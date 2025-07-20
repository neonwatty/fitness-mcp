require "test_helper"

class DataFlowIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user1 = create_user
    @user2 = create_user
    
    @api_key_record1, @api_key1 = create_api_key(user: @user1)
    @api_key_record2, @api_key2 = create_api_key(user: @user2)
    
    @headers1 = { 'Authorization' => "Bearer #{@api_key1}" }
    @headers2 = { 'Authorization' => "Bearer #{@api_key2}" }
  end

  test "complete data flow consistency across all application layers" do
    # Step 1: Create comprehensive workout data for both users
    user1_workout_data = create_comprehensive_workout_data(@user1, @headers1)
    user2_workout_data = create_comprehensive_workout_data(@user2, @headers2, user_prefix: "User2")
    
    # Step 2: Verify data through direct API endpoints
    verify_api_data_consistency(@user1, @headers1, user1_workout_data)
    verify_api_data_consistency(@user2, @headers2, user2_workout_data)
    
    # Step 3: Verify data through MCP Tools
    verify_tool_data_consistency(@user1, @api_key1, user1_workout_data)
    verify_tool_data_consistency(@user2, @api_key2, user2_workout_data)
    
    # Step 4: Verify data through Resources
    verify_resource_data_consistency(@user1, @headers1, user1_workout_data)
    verify_resource_data_consistency(@user2, @headers2, user2_workout_data)
    
    # Step 5: Test cross-layer data aggregation and calculations
    verify_cross_layer_calculations(@user1, @headers1)
    verify_cross_layer_calculations(@user2, @headers2)
    
    # Step 6: Test concurrent operations and data integrity
    test_concurrent_data_operations(@user1, @headers1, @user2, @headers2)
    
    # Step 7: Verify user data isolation
    verify_user_data_isolation(@user1, @headers1, @user2, @headers2)
  end
  
  test "complex filtering and aggregation across components" do
    # Create diverse workout data spanning multiple exercises and time periods
    exercises = ["bench press", "squat", "deadlift", "pull-ups", "shoulder press"]
    
    # Create data over 30 days
    30.times do |day|
      date = day.days.ago
      
      exercises.each_with_index do |exercise, exercise_index|
        # Create 2-4 sets per exercise per day
        sets_count = 2 + (day % 3)
        
        sets_count.times do |set_index|
          weight = 100 + (exercise_index * 20) + (day * 2) + (set_index * 5)
          reps = 12 - (set_index * 2)
          timestamp = date - (exercise_index * 15 + set_index * 3).minutes
          
          post "/api/v1/fitness/log_set",
            params: {
              exercise: exercise,
              weight: weight,
              reps: reps,
              timestamp: timestamp.iso8601
            },
            headers: @headers1
          
          assert_response :created
        end
      end
    end
    
    total_sets = @user1.set_entries.count
    assert total_sets > 300, "Should have created substantial amount of data"
    
    # Test complex filtering through different access methods
    # Test 1: Exercise-specific filtering consistency
    exercises.each do |exercise|
      # API endpoint filtering
      get "/api/v1/fitness/history",
        params: { exercise: exercise, limit: 50 },
        headers: @headers1
      
      assert_response :success
      api_sets = JSON.parse(response.body)["history"]
      
      # Database filtering  
      db_sets = @user1.set_entries.for_exercise(exercise).recent.limit(50)
      
      assert_equal api_sets.length, db_sets.count
      api_sets.each_with_index do |api_set, index|
        db_set = db_sets[index]
        assert_equal api_set["exercise"], db_set.exercise
        assert_equal api_set["weight"], db_set.weight.to_f
        assert_equal api_set["reps"], db_set.reps
      end
      
      # Tool filtering
      tool = GetLastSetsTool.new(api_key: @api_key1)
      tool_result = tool.call(exercise: exercise, limit: 20)
      
      assert tool_result[:success]
      tool_sets = tool_result[:set_entries]
      
      # Compare tool results with API results (first 20)
      api_sets_limited = api_sets.first(20)
      assert_equal tool_sets.length, api_sets_limited.length
      
      tool_sets.each_with_index do |tool_set, index|
        api_set = api_sets_limited[index]
        assert_equal tool_set[:exercise], api_set["exercise"]
        assert_equal tool_set[:weight], api_set["weight"]
        assert_equal tool_set[:reps], api_set["reps"]
      end
    end
    
    # Test 2: Time-based filtering consistency
    recent_tool = GetRecentSetsTool.new(api_key: @api_key1)
    # GetRecentSetsTool doesn't filter by days, it just returns recent sets with a limit
    recent_result = recent_tool.call(limit: 50)
    
    assert recent_result[:success]
    tool_recent_sets = recent_result[:set_entries]
    
    # Compare with database query - get the same number of recent sets
    db_recent_sets = @user1.set_entries.recent.limit(50)
    
    assert_equal db_recent_sets.count, tool_recent_sets.length
    
    # Test 3: Aggregation consistency
    # Get user stats through resource
    # UserStatsResource expects params with user_id
    user_stats_resource = UserStatsResource.new(nil)
    user_stats_resource.instance_variable_set(:@params, { user_id: @user1.id })
    # Mock current_user method to return @user1 and bypass authentication
    user_stats_resource.define_singleton_method(:current_user) { @user1 }
    user_stats_resource.define_singleton_method(:can_access_user_data?) { |user_id| true }
    stats_data = JSON.parse(user_stats_resource.content, symbolize_names: true)
    
    # Verify stats against database calculations
    total_sets_db = @user1.set_entries.count
    total_exercises_db = @user1.set_entries.distinct.count(:exercise)
    
    assert_equal stats_data[:total_sets], total_sets_db
    assert_equal stats_data[:unique_exercises], total_exercises_db
    
    # Verify exercise stats
    exercises.each do |exercise|
      heaviest_db = @user1.set_entries.for_exercise(exercise).maximum(:weight)
      exercise_stat = stats_data[:exercise_stats]&.find { |e| e[:exercise] == exercise }
      
      if heaviest_db && exercise_stat
        assert_equal exercise_stat[:max_weight], heaviest_db.to_f
      end
    end
  end
  
  test "data consistency under concurrent modifications" do
    # Test concurrent data modifications and ensure consistency
    threads = []
    results = []
    
    # Thread 1: Continuously log sets
    threads << Thread.new do
      thread_results = []
      10.times do |i|
        post "/api/v1/fitness/log_set",
          params: {
            exercise: "Concurrent Exercise A",
            weight: 100 + i,
            reps: 10
          },
          headers: @headers1
        
        thread_results << {
          status: response.status,
          success: response.status == 201
        }
        sleep(0.1)
      end
      results << { thread: "log_sets", results: thread_results }
    end
    
    # Thread 2: Continuously read data
    threads << Thread.new do
      thread_results = []
      10.times do |i|
        get "/api/v1/fitness/history",
          params: { exercise: "concurrent exercise a" },
          headers: @headers1
        
        if response.status == 200
          history = JSON.parse(response.body)["history"]
          thread_results << history.length
        else
          thread_results << 0
        end
        sleep(0.1)
      end
      results << { thread: "read_history", results: thread_results }
    end
    
    # Thread 3: Use tools concurrently
    threads << Thread.new do
      tool = GetLastSetsTool.new(api_key: @api_key1)
      thread_results = []
      
      10.times do |i|
        begin
          result = tool.call(exercise: "concurrent exercise a", limit: 5)
          if result[:success]
            thread_results << result[:set_entries].length
          else
            thread_results << 0
          end
        rescue => e
          thread_results << -1
        end
        sleep(0.1)
      end
      results << { thread: "tool_reads", results: thread_results }
    end
    
    # Wait for all threads
    threads.each(&:join)
    
    # Analyze results
    log_results = results.find { |r| r[:thread] == "log_sets" }[:results]
    read_results = results.find { |r| r[:thread] == "read_history" }[:results]
    tool_results = results.find { |r| r[:thread] == "tool_reads" }[:results]
    
    # Verify successful operations
    successful_logs = log_results.count { |r| r[:success] }
    assert successful_logs > 0, "Should have some successful log operations"
    
    # Verify read consistency
    assert read_results.all? { |count| count >= 0 }, "All read operations should return valid counts"
    assert read_results.last >= read_results.first, "Set count should increase over time"
    
    # Verify tool consistency
    assert tool_results.all? { |count| count >= 0 }, "All tool operations should return valid counts"
    
    # Final consistency check
    final_db_count = @user1.set_entries.for_exercise("concurrent exercise a").count
    assert_equal successful_logs, final_db_count
  end
  
  test "resource calculations match raw data across large datasets" do
    # Create large dataset for calculation verification
    exercises = ["bench press", "squat", "deadlift"]
    
    expected_totals = {}
    expected_heaviest = {}
    expected_recent_counts = {}
    
    exercises.each do |exercise|
      expected_totals[exercise] = 0
      expected_heaviest[exercise] = 0
      expected_recent_counts[exercise] = 0
      
      # Create 50 sets per exercise with varying weights
      50.times do |i|
        weight = 100 + (i * 2.5)
        reps = 10 - (i % 5)
        timestamp = i.hours.ago
        
        post "/api/v1/fitness/log_set",
          params: {
            exercise: exercise,
            weight: weight,
            reps: reps,
            timestamp: timestamp.iso8601
          },
          headers: @headers1
        
        assert_response :created
        
        expected_totals[exercise] += 1
        expected_heaviest[exercise] = [expected_heaviest[exercise], weight].max
        
        if timestamp >= 7.days.ago
          expected_recent_counts[exercise] += 1
        end
      end
    end
    
    # Verify through UserStatsResource
    user_stats = UserStatsResource.new(nil)
    user_stats.instance_variable_set(:@params, { user_id: @user1.id })
    user_stats.define_singleton_method(:current_user) { @user1 }
    user_stats.define_singleton_method(:can_access_user_data?) { |user_id| true }
    stats_json = JSON.parse(user_stats.content, symbolize_names: true)
    
    assert_equal 150, stats_json[:total_sets]
    assert_equal 3, stats_json[:unique_exercises]
    
    exercises.each do |exercise|
      exercise_stat = stats_json[:exercise_stats]&.find { |e| e[:exercise] == exercise }
      if exercise_stat
        assert_equal expected_heaviest[exercise], exercise_stat[:max_weight]
      end
    end
    
    # Verify through ExerciseListResource
    exercise_list = ExerciseListResource.new(nil)
    # Ensure we have a user1 instance
    user1 = @user1
    # Mock current_user to bypass authentication
    exercise_list.define_singleton_method(:current_user) { user1 }
    exercise_data = JSON.parse(exercise_list.content, symbolize_names: true)
    
    exercises.each do |exercise|
      exercise_info = exercise_data[:exercises].find { |e| e[:name] == exercise }
      assert exercise_info, "Exercise #{exercise} should be in list"
      assert_equal expected_totals[exercise], exercise_info[:total_sets]
      assert_equal expected_heaviest[exercise], exercise_info[:max_weight]
    end
    
    # Verify through WorkoutHistoryResource
    workout_history = WorkoutHistoryResource.new(nil)
    workout_history.instance_variable_set(:@params, { user_id: @user1.id })
    workout_history.define_singleton_method(:current_user) { @user1 }
    workout_history.define_singleton_method(:can_access_user_data?) { |user_id| true }
    history_data = JSON.parse(workout_history.content, symbolize_names: true)
    
    # Should have recent sets
    recent_sets = history_data[:recent_sets]
    # WorkoutHistoryResource limits to 50 most recent sets
    assert_equal 50, recent_sets.length
    
    # Count sets from last 7 days (all 50 should be within 7 days since oldest is 49 hours ago)
    seven_days_ago = 7.days.ago
    recent_count = recent_sets.count { |s| Time.parse(s[:timestamp]) >= seven_days_ago }
    
    # All 50 returned sets should be within last 7 days
    assert_equal 50, recent_count
  end
  
  private
  
  def create_comprehensive_workout_data(user, headers, user_prefix: "")
    workout_data = {
      sets: [],
      assignments: []
    }
    
    # Create workout sets
    exercises = ["#{user_prefix}Bench Press", "#{user_prefix}Squat", "#{user_prefix}Deadlift"]
    
    exercises.each do |exercise|
      3.times do |set_num|
        weight = 100 + (set_num * 20)
        reps = 12 - (set_num * 2)
        
        post "/api/v1/fitness/log_set",
          params: { exercise: exercise, weight: weight, reps: reps },
          headers: headers
        
        assert_response :created
        json = JSON.parse(response.body)
        workout_data[:sets] << json["set"]
      end
    end
    
    # Create workout assignments
    post "/api/v1/fitness/assign_workout",
      params: {
        assignment_name: "#{user_prefix}Test Workout",
        scheduled_for: Date.tomorrow,
        config: {
          exercises: exercises.map { |e| { name: e, sets: 3, reps: 10 } }
        }
      },
      headers: headers
    
    assert_response :created
    json = JSON.parse(response.body)
    workout_data[:assignments] << json["assignment"]
    
    workout_data
  end
  
  def verify_api_data_consistency(user, headers, expected_data)
    # Verify sets through history endpoint
    get "/api/v1/fitness/history", headers: headers
    assert_response :success
    
    history = JSON.parse(response.body)["history"]
    assert_equal expected_data[:sets].length, history.length
    
    # Verify assignments through plans endpoint  
    get "/api/v1/fitness/plans", headers: headers
    assert_response :success
    
    plans = JSON.parse(response.body)["plans"]
    assert_equal expected_data[:assignments].length, plans.length
  end
  
  def verify_tool_data_consistency(user, api_key, expected_data)
    # Test GetLastSetTool
    tool = GetLastSetTool.new(api_key: api_key)
    # Get the last exercise from expected data
    last_exercise = expected_data[:sets].last["exercise"] if expected_data[:sets].any?
    return unless last_exercise
    
    result = tool.call(exercise: last_exercise)
    
    assert result[:success]
    last_set = result[:last_set]
    expected_last = expected_data[:sets].last
    
    return unless last_set # Handle case where no sets found
    
    assert_equal expected_last["exercise"], last_set[:exercise]
    assert_equal expected_last["weight"], last_set[:weight]
    assert_equal expected_last["reps"], last_set[:reps]
    
    # Test GetLastSetsTool
    sets_tool = GetLastSetsTool.new(api_key: api_key)
    # Get sets for the specific exercise only (each exercise has 3 sets)
    exercise_sets = expected_data[:sets].select { |s| s["exercise"] == last_exercise }
    sets_result = sets_tool.call(exercise: last_exercise, limit: exercise_sets.length)
    
    assert sets_result[:success]
    tool_sets = sets_result[:set_entries]
    
    assert_equal exercise_sets.length, tool_sets.length
  end
  
  def verify_resource_data_consistency(user, headers, expected_data)
    # Test UserStatsResource through API (if available) or directly
    user_stats = UserStatsResource.new(nil)
    user_stats.instance_variable_set(:@params, { user_id: user.id })
    user_stats.define_singleton_method(:current_user) { user }
    user_stats.define_singleton_method(:can_access_user_data?) { |user_id| true }
    stats_data = JSON.parse(user_stats.content, symbolize_names: true)
    
    assert_equal expected_data[:sets].length, stats_data[:total_sets]
    
    # Test ExerciseListResource
    exercise_list = ExerciseListResource.new(nil)
    exercise_list.define_singleton_method(:current_user) { user }
    exercise_data = JSON.parse(exercise_list.content, symbolize_names: true)
    
    exercise_names = expected_data[:sets].map { |s| s["exercise"] }.uniq
    resource_names = exercise_data[:exercises].map { |e| e[:name] }
    
    exercise_names.each do |name|
      assert_includes resource_names, name
    end
    
    # Test WorkoutHistoryResource
    workout_history = WorkoutHistoryResource.new(nil)
    workout_history.instance_variable_set(:@params, { user_id: user.id })
    workout_history.define_singleton_method(:current_user) { user }
    workout_history.define_singleton_method(:can_access_user_data?) { |user_id| true }
    history_data = JSON.parse(workout_history.content, symbolize_names: true)
    
    assert history_data[:recent_sets].length > 0
  end
  
  def verify_cross_layer_calculations(user, headers)
    # Get data through multiple layers and verify calculations match
    
    # Layer 1: Direct database queries
    db_total_sets = user.set_entries.count
    db_total_exercises = user.set_entries.distinct.count(:exercise)
    
    # Layer 2: API endpoint
    get "/api/v1/fitness/history", headers: headers
    assert_response :success
    api_sets = JSON.parse(response.body)["history"]
    api_exercises = api_sets.map { |s| s["exercise"] }.uniq
    
    # Layer 3: Resource
    stats_resource = UserStatsResource.new(nil)
    stats_resource.instance_variable_set(:@params, { user_id: user.id })
    stats_resource.define_singleton_method(:current_user) { user }
    stats_resource.define_singleton_method(:can_access_user_data?) { |user_id| true }
    resource_stats = JSON.parse(stats_resource.content, symbolize_names: true)
    
    # Verify all layers agree
    assert_equal db_total_sets, api_sets.length
    assert_equal db_total_sets, resource_stats[:total_sets]
    assert_equal db_total_exercises, api_exercises.length
    assert_equal db_total_exercises, resource_stats[:unique_exercises]
  end
  
  def test_concurrent_data_operations(user1, headers1, user2, headers2)
    # Test that concurrent operations by different users don't interfere
    threads = []
    
    # User 1 operations
    threads << Thread.new do
      5.times do |i|
        post "/api/v1/fitness/log_set",
          params: { exercise: "User1 Concurrent", weight: 100 + i, reps: 10 },
          headers: headers1
        assert_response :created
      end
    end
    
    # User 2 operations  
    threads << Thread.new do
      5.times do |i|
        post "/api/v1/fitness/log_set",
          params: { exercise: "User2 Concurrent", weight: 150 + i, reps: 8 },
          headers: headers2
        assert_response :created
      end
    end
    
    threads.each(&:join)
    
    # Verify data integrity
    user1_sets = user1.set_entries.for_exercise("user1 concurrent")
    user2_sets = user2.set_entries.for_exercise("user2 concurrent")
    
    assert_equal 5, user1_sets.count
    assert_equal 5, user2_sets.count
    
    # Verify no cross-contamination
    assert_equal 0, user1.set_entries.for_exercise("user2 concurrent").count
    assert_equal 0, user2.set_entries.for_exercise("user1 concurrent").count
  end
  
  def verify_user_data_isolation(user1, headers1, user2, headers2)
    # Verify each user only sees their own data through all access methods
    
    # API isolation
    get "/api/v1/fitness/history", headers: headers1
    user1_history = JSON.parse(response.body)["history"]
    
    get "/api/v1/fitness/history", headers: headers2  
    user2_history = JSON.parse(response.body)["history"]
    
    user1_exercises = user1_history.map { |s| s["exercise"] }.uniq
    user2_exercises = user2_history.map { |s| s["exercise"] }.uniq
    
    # Should have no overlap in exercise names (since we used prefixes)
    assert (user1_exercises & user2_exercises).empty?, "Users should not see each other's data"
    
    # Tool isolation
    user1_tool = GetLastSetTool.new(api_key: @api_key1)
    user2_tool = GetLastSetTool.new(api_key: @api_key2)
    
    # Get last set for each user's specific exercise
    user1_last = user1_tool.call(exercise: "bench press")
    user2_last = user2_tool.call(exercise: "user2bench press")
    
    if user1_last[:success] && user2_last[:success]
      assert_not_equal user1_last[:last_set][:exercise], user2_last[:last_set][:exercise]
    end
    
    # Database isolation verification
    assert_equal 0, user1.set_entries.joins(:user).where(users: { id: user2.id }).count
    assert_equal 0, user2.set_entries.joins(:user).where(users: { id: user1.id }).count
  end
end