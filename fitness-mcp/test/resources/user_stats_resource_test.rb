require "test_helper"

class UserStatsResourceTest < ActiveSupport::TestCase
  def setup
    @user1 = create_user(email: "user1@example.com")
    @user2 = create_user(email: "user2@example.com")
    @api_key_record1, @api_key1 = create_api_key(user: @user1)
    @api_key_record2, @api_key2 = create_api_key(user: @user2)
    
    # Create test data with different timestamps
    @old_sets = [
      @user1.set_entries.create!(exercise: "Squat", weight: 185.0, reps: 8, timestamp: 45.days.ago),
      @user1.set_entries.create!(exercise: "Bench Press", weight: 135.0, reps: 10, timestamp: 35.days.ago)
    ]
    
    @recent_sets = [
      @user1.set_entries.create!(exercise: "Squat", weight: 205.0, reps: 8, timestamp: 15.days.ago),
      @user1.set_entries.create!(exercise: "Squat", weight: 225.0, reps: 5, timestamp: 10.days.ago),
      @user1.set_entries.create!(exercise: "Bench Press", weight: 145.0, reps: 8, timestamp: 8.days.ago),
      @user1.set_entries.create!(exercise: "Deadlift", weight: 275.0, reps: 5, timestamp: 5.days.ago),
      @user1.set_entries.create!(exercise: "Deadlift", weight: 285.0, reps: 3, timestamp: 2.days.ago)
    ]
    
    # Create workout assignments
    @user1.workout_assignments.create!(
      assignment_name: "Active Workout",
      config: '{"exercises": ["Squat", "Bench"]}',
      scheduled_for: 1.day.from_now
    )
    
    @resource = UserStatsResource.new
  end

  test "should generate user stats with valid authentication" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    # Basic user info
    assert_equal @user1.id, data["user_id"]
    assert_equal @user1.email, data["user_email"]
    assert_equal 30, data["period_days"]
    
    # Overall statistics
    assert_equal 7, data["total_sets"] # All sets (old + recent)
    assert_equal 5, data["recent_sets"] # Only recent sets (last 30 days)
    
    # Weight calculations
    total_weight = (185*8 + 135*10 + 205*8 + 225*5 + 145*8 + 275*5 + 285*3)
    recent_weight = (205*8 + 225*5 + 145*8 + 275*5 + 285*3)
    assert_equal total_weight, data["total_weight_moved"]
    assert_equal recent_weight, data["recent_weight_moved"]
    
    # Exercise diversity
    assert_equal 3, data["unique_exercises"] # Squat, Bench Press, Deadlift
    assert_equal 3, data["recent_exercises"] # Same 3 in recent period
    
    # Assignments
    assert_equal 1, data["active_assignments"]
    
    # Activity tracking
    assert data["last_workout"]
    assert data["days_since_last_workout"]
    assert data["days_since_last_workout"] < 30
    
    # Exercise stats
    assert data["exercise_stats"]
    assert data["exercise_stats"].is_a?(Array)
    assert data["exercise_stats"].length > 0
    
    # Strength progress
    assert data["strength_progress"]
    assert data["strength_progress"].is_a?(Array)
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should require authentication" do
    ENV.delete('API_KEY')
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Access denied to user #{@user1.id} statistics", error.message
  end
  
  test "should deny access to other user's data" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user2.id })
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Access denied to user #{@user2.id} statistics", error.message
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should allow access to own data" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    # Should not raise an error
    assert_nothing_raised do
      @resource.content
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should calculate exercise stats correctly" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    exercise_stats = data["exercise_stats"]
    squat_stats = exercise_stats.find { |ex| ex["exercise"] == "Squat" }
    bench_stats = exercise_stats.find { |ex| ex["exercise"] == "Bench Press" }
    deadlift_stats = exercise_stats.find { |ex| ex["exercise"] == "Deadlift" }
    
    # Squat stats (2 recent sets: 205x8, 225x5)
    assert_equal 2, squat_stats["total_sets"]
    assert_equal 13, squat_stats["total_reps"] # 8 + 5
    assert_equal 2765, squat_stats["total_weight"] # 205*8 + 225*5
    assert_equal 225.0, squat_stats["max_weight"]
    assert_equal 215.0, squat_stats["average_weight"] # (205 + 225) / 2
    assert squat_stats["last_performed"]
    
    # Bench Press stats (1 recent set: 145x8)
    assert_equal 1, bench_stats["total_sets"]
    assert_equal 8, bench_stats["total_reps"]
    assert_equal 1160, bench_stats["total_weight"] # 145*8
    assert_equal 145.0, bench_stats["max_weight"]
    assert_equal 145.0, bench_stats["average_weight"]
    
    # Deadlift stats (2 recent sets: 275x5, 285x3)
    assert_equal 2, deadlift_stats["total_sets"]
    assert_equal 8, deadlift_stats["total_reps"] # 5 + 3
    assert_equal 2230, deadlift_stats["total_weight"] # 275*5 + 285*3
    assert_equal 285.0, deadlift_stats["max_weight"]
    assert_equal 280.0, deadlift_stats["average_weight"] # (275 + 285) / 2
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should calculate strength progress correctly" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    strength_progress = data["strength_progress"]
    squat_progress = strength_progress.find { |ex| ex["exercise"] == "squat" }
    deadlift_progress = strength_progress.find { |ex| ex["exercise"] == "deadlift" }
    
    # Squat progress (first: 205, last: 225)
    assert_equal "squat", squat_progress["exercise"]
    assert_equal 205.0, squat_progress["first_weight"]
    assert_equal 225.0, squat_progress["last_weight"]
    assert_equal 20.0, squat_progress["improvement"]
    assert_equal 9.76, squat_progress["improvement_percentage"] # (20/205)*100 rounded to 2 decimal places
    assert_equal 2, squat_progress["sets_performed"]
    
    # Deadlift progress (first: 275, last: 285)
    assert_equal "deadlift", deadlift_progress["exercise"]
    assert_equal 275.0, deadlift_progress["first_weight"]
    assert_equal 285.0, deadlift_progress["last_weight"]
    assert_equal 10.0, deadlift_progress["improvement"]
    assert_equal 3.64, deadlift_progress["improvement_percentage"] # (10/275)*100 rounded
    assert_equal 2, deadlift_progress["sets_performed"]
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle user with no sets" do
    user_no_sets = create_user(email: "nosets@example.com")
    api_key_record, api_key = create_api_key(user: user_no_sets)
    
    ENV['API_KEY'] = api_key
    @resource.instance_variable_set(:@params, { user_id: user_no_sets.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    assert_equal 0, data["total_sets"]
    assert_equal 0, data["recent_sets"]
    assert_equal 0, data["total_weight_moved"]
    assert_equal 0, data["recent_weight_moved"]
    assert_equal 0, data["unique_exercises"]
    assert_equal 0, data["recent_exercises"]
    assert_equal [], data["exercise_stats"]
    assert_equal [], data["strength_progress"]
    assert_nil data["last_workout"]
    assert_nil data["days_since_last_workout"]
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle user with only old sets" do
    user_old_sets = create_user(email: "oldsets@example.com")
    api_key_record, api_key = create_api_key(user: user_old_sets)
    
    # Create only old sets (outside 30-day window)
    user_old_sets.set_entries.create!(exercise: "Old Exercise", weight: 100.0, reps: 10, timestamp: 40.days.ago)
    
    ENV['API_KEY'] = api_key
    @resource.instance_variable_set(:@params, { user_id: user_old_sets.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    assert_equal 1, data["total_sets"]
    assert_equal 0, data["recent_sets"] # No recent sets
    assert_equal 1000, data["total_weight_moved"]
    assert_equal 0, data["recent_weight_moved"] # No recent weight
    assert_equal 1, data["unique_exercises"]
    assert_equal 0, data["recent_exercises"] # No recent exercises
    assert_equal [], data["exercise_stats"] # No recent exercise stats
    assert_equal [], data["strength_progress"] # No recent progress
    assert data["last_workout"]
    assert data["days_since_last_workout"] > 30
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle invalid user id" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: 99999 })
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Access denied to user 99999 statistics", error.message
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle string user id" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id.to_s })
    
    # Should work with string user_id
    assert_nothing_raised do
      content = @resource.content
      data = JSON.parse(content)
      assert_equal @user1.id, data["user_id"]
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should return valid JSON" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    
    # Should be valid JSON
    assert_nothing_raised do
      JSON.parse(content)
    end
    
    # Should be pretty formatted (contains newlines)
    assert_includes content, "\n"
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should have correct resource metadata" do
    assert_equal "fitness://stats/{user_id}", UserStatsResource.uri
    assert_equal "User Statistics", UserStatsResource.resource_name
    assert_equal "Comprehensive fitness statistics and analytics for a user", UserStatsResource.description
    assert_equal "application/json", UserStatsResource.mime_type
  end
  
  test "should inherit from FastMcp::Resource" do
    assert UserStatsResource < FastMcp::Resource
  end
  
  test "should handle exercises with special characters" do
    # Create sets with special exercise names
    @user1.set_entries.create!(exercise: "Dumbbell Press", weight: 50.0, reps: 12, timestamp: 5.days.ago)
    @user1.set_entries.create!(exercise: "Romanian Deadlift", weight: 185.0, reps: 8, timestamp: 3.days.ago)
    
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    exercise_names = data["exercise_stats"].map { |ex| ex["exercise"] }
    assert_includes exercise_names, "Dumbbell Press"
    assert_includes exercise_names, "Romanian Deadlift"
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should calculate days since last workout correctly" do
    # Clear existing sets and create one with known timestamp
    @user1.set_entries.destroy_all
    last_workout_time = 5.days.ago
    @user1.set_entries.create!(exercise: "Test", weight: 100.0, reps: 10, timestamp: last_workout_time)
    
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    # Should be approximately 5 days (allowing for small timing differences)
    assert data["days_since_last_workout"].between?(4, 6)
    assert_equal last_workout_time.iso8601, data["last_workout"]
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle nil timestamps gracefully" do
    # Create set with nil timestamp (shouldn't normally happen but test resilience)
    set = @user1.set_entries.build(exercise: "Test", weight: 100.0, reps: 10, timestamp: nil)
    set.save(validate: false)
    
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    # Should not crash
    assert_nothing_raised do
      @resource.content
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle edge case of zero weight" do
    # Test division by zero protection
    @user1.set_entries.destroy_all
    @user1.set_entries.create!(exercise: "Squat", weight: 0.0, reps: 10, timestamp: 5.days.ago)
    @user1.set_entries.create!(exercise: "Squat", weight: 100.0, reps: 10, timestamp: 3.days.ago)
    
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    # Should handle gracefully without division by zero errors
    assert_nothing_raised do
      content = @resource.content
      data = JSON.parse(content)
      
      # Should have strength progress despite zero starting weight
      squat_progress = data["strength_progress"].find { |ex| ex["exercise"] == "squat" }
      assert squat_progress
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  def teardown
    # Ensure ENV is clean after each test
    ENV.delete('API_KEY')
  end
end