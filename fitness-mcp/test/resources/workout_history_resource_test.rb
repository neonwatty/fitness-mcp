require "test_helper"

class WorkoutHistoryResourceTest < ActiveSupport::TestCase
  def setup
    @user1 = create_user(email: "user1@example.com")
    @user2 = create_user(email: "user2@example.com")
    @api_key_record1, @api_key1 = create_api_key(user: @user1)
    @api_key_record2, @api_key2 = create_api_key(user: @user2)
    
    # Create test workout history with different timestamps
    @sets = []
    
    # Create 60 sets to test the limit of 50
    60.times do |i|
      @sets << @user1.set_entries.create!(
        exercise: "Exercise #{i % 5}", # 5 different exercises
        weight: 100.0 + i,
        reps: 8 + (i % 5),
        timestamp: (60 - i).hours.ago
      )
    end
    
    # Create some sets for user2 to test access control
    @user2.set_entries.create!(
      exercise: "User2 Exercise",
      weight: 150.0,
      reps: 10,
      timestamp: 1.day.ago
    )
    
    @resource = WorkoutHistoryResource.new
  end

  test "should generate workout history with valid authentication" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    # Basic user info
    assert_equal @user1.id, data["user_id"]
    assert_equal @user1.email, data["user_email"]
    
    # Should show total count but limit recent sets to 50
    assert_equal 60, data["total_sets"]
    assert_equal 50, data["recent_sets"].length
    
    # Check structure of recent sets
    recent_set = data["recent_sets"].first
    assert recent_set["id"]
    assert recent_set["exercise"]
    assert recent_set["weight"]
    assert recent_set["reps"]
    assert recent_set["timestamp"]
    assert recent_set["created_at"]
    
    # Should be ordered by timestamp descending (most recent first)
    timestamps = data["recent_sets"].map { |set| Time.iso8601(set["timestamp"]) }
    assert_equal timestamps, timestamps.sort.reverse
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should require authentication" do
    ENV.delete('API_KEY')
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Access denied to user #{@user1.id} workout history", error.message
  end
  
  test "should deny access to other user's data" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user2.id })
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Access denied to user #{@user2.id} workout history", error.message
    
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
  
  test "should handle user with no workout history" do
    user_no_history = create_user(email: "nohistory@example.com")
    api_key_record, api_key = create_api_key(user: user_no_history)
    
    ENV['API_KEY'] = api_key
    @resource.instance_variable_set(:@params, { user_id: user_no_history.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    assert_equal user_no_history.id, data["user_id"]
    assert_equal user_no_history.email, data["user_email"]
    assert_equal 0, data["total_sets"]
    assert_equal [], data["recent_sets"]
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle user with less than 50 sets" do
    user_few_sets = create_user(email: "fewsets@example.com")
    api_key_record, api_key = create_api_key(user: user_few_sets)
    
    # Create only 10 sets
    10.times do |i|
      user_few_sets.set_entries.create!(
        exercise: "Exercise #{i}",
        weight: 100.0,
        reps: 10,
        timestamp: (10 - i).hours.ago
      )
    end
    
    ENV['API_KEY'] = api_key
    @resource.instance_variable_set(:@params, { user_id: user_few_sets.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    assert_equal 10, data["total_sets"]
    assert_equal 10, data["recent_sets"].length
    
    # Should still be ordered correctly
    timestamps = data["recent_sets"].map { |set| Time.iso8601(set["timestamp"]) }
    assert_equal timestamps, timestamps.sort.reverse
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should include all required fields in recent sets" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    recent_set = data["recent_sets"].first
    
    # Check all required fields are present
    required_fields = %w[id exercise weight reps timestamp created_at]
    required_fields.each do |field|
      assert recent_set.key?(field), "Missing field: #{field}"
      assert_not_nil recent_set[field], "Field #{field} is nil"
    end
    
    # Check data types
    assert_instance_of Integer, recent_set["id"]
    assert_instance_of String, recent_set["exercise"]
    assert recent_set["weight"].is_a?(Numeric)
    assert_instance_of Integer, recent_set["reps"]
    assert_instance_of String, recent_set["timestamp"]
    assert_instance_of String, recent_set["created_at"]
    
    # Check timestamp formats (should be ISO8601)
    assert_nothing_raised do
      Time.iso8601(recent_set["timestamp"])
      Time.iso8601(recent_set["created_at"])
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle invalid user id" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: 99999 })
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Access denied to user 99999 workout history", error.message
    
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
  
  test "should fail with invalid API key" do
    ENV['API_KEY'] = "invalid_key_123"
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Access denied to user #{@user1.id} workout history", error.message
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should fail with revoked API key" do
    @api_key_record1.revoke!
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Access denied to user #{@user1.id} workout history", error.message
    
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
    assert_equal "fitness://history/{user_id}", WorkoutHistoryResource.uri
    assert_equal "Workout History", WorkoutHistoryResource.resource_name
    assert_equal "Complete workout history for a user including all logged sets", WorkoutHistoryResource.description
    assert_equal "application/json", WorkoutHistoryResource.mime_type
  end
  
  test "should inherit from FastMcp::Resource" do
    assert WorkoutHistoryResource < FastMcp::Resource
  end
  
  test "should handle sets with special exercise names" do
    @user1.set_entries.destroy_all
    
    # Create sets with various exercise names
    special_exercises = [
      "Barbell Back Squat",
      "Dumbbell Bench Press",
      "Romanian Deadlift",
      "Bulgarian Split Squat",
      "Single-Arm Row"
    ]
    
    special_exercises.each_with_index do |exercise, i|
      @user1.set_entries.create!(
        exercise: exercise,
        weight: 100.0 + i * 10,
        reps: 8 + i,
        timestamp: (i + 1).hours.ago
      )
    end
    
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    exercise_names = data["recent_sets"].map { |set| set["exercise"] }
    special_exercises.each do |exercise|
      assert_includes exercise_names, exercise
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle sets with edge case values" do
    @user1.set_entries.destroy_all
    
    # Create sets with edge case values
    edge_cases = [
      { exercise: "Light Exercise", weight: 0.5, reps: 1 },
      { exercise: "Heavy Exercise", weight: 999.9, reps: 50 },
      { exercise: "High Rep Exercise", weight: 10.0, reps: 100 }
    ]
    
    edge_cases.each_with_index do |set_data, i|
      @user1.set_entries.create!(
        exercise: set_data[:exercise],
        weight: set_data[:weight],
        reps: set_data[:reps],
        timestamp: (i + 1).hours.ago
      )
    end
    
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    # Should handle edge cases without error
    assert_nothing_raised do
      content = @resource.content
      data = JSON.parse(content)
      
      assert_equal 3, data["total_sets"]
      assert_equal 3, data["recent_sets"].length
      
      # Check that all edge case values are preserved
      light_set = data["recent_sets"].find { |s| s["exercise"] == "Light Exercise" }
      assert_equal 0.5, light_set["weight"]
      assert_equal 1, light_set["reps"]
      
      heavy_set = data["recent_sets"].find { |s| s["exercise"] == "Heavy Exercise" }
      assert_equal 999.9, heavy_set["weight"]
      assert_equal 50, heavy_set["reps"]
      
      high_rep_set = data["recent_sets"].find { |s| s["exercise"] == "High Rep Exercise" }
      assert_equal 10.0, high_rep_set["weight"]
      assert_equal 100, high_rep_set["reps"]
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should limit results to exactly 50 sets when user has more" do
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    content = @resource.content
    data = JSON.parse(content)
    
    # User has 60 sets, but should only return 50 recent ones
    assert_equal 60, data["total_sets"]
    assert_equal 50, data["recent_sets"].length
    
    # The 50 returned should be the most recent ones
    returned_timestamps = data["recent_sets"].map { |set| Time.iso8601(set["timestamp"]) }
    all_timestamps = @user1.set_entries.order(timestamp: :desc).limit(50).pluck(:timestamp)
    
    assert_equal all_timestamps.map(&:to_i), returned_timestamps.map(&:to_i)
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle nil timestamps gracefully" do
    @user1.set_entries.destroy_all
    
    # Create set with nil timestamp (shouldn't normally happen but test resilience)
    set = @user1.set_entries.build(exercise: "Test", weight: 100.0, reps: 10, timestamp: nil)
    set.save(validate: false)
    
    ENV['API_KEY'] = @api_key1
    @resource.instance_variable_set(:@params, { user_id: @user1.id })
    
    # Should not crash but may not include the set with nil timestamp in results
    assert_nothing_raised do
      @resource.content
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  def teardown
    # Ensure ENV is clean after each test
    ENV.delete('API_KEY')
  end
end