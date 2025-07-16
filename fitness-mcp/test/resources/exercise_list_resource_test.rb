require "test_helper"

class ExerciseListResourceTest < ActiveSupport::TestCase
  def setup
    @user1 = create_user(email: "user1@example.com")
    @user2 = create_user(email: "user2@example.com")
    @api_key_record, @api_key = create_api_key(user: @user1)
    
    # Create test set entries with different exercises and users
    @bench_press_sets = [
      @user1.set_entries.create!(exercise: "Bench Press", weight: 135.0, reps: 10, timestamp: 3.days.ago),
      @user1.set_entries.create!(exercise: "Bench Press", weight: 145.0, reps: 8, timestamp: 2.days.ago),
      @user2.set_entries.create!(exercise: "Bench Press", weight: 155.0, reps: 6, timestamp: 1.day.ago)
    ]
    
    @squat_sets = [
      @user1.set_entries.create!(exercise: "Squat", weight: 185.0, reps: 8, timestamp: 2.days.ago),
      @user2.set_entries.create!(exercise: "Squat", weight: 225.0, reps: 5, timestamp: 1.day.ago)
    ]
    
    @deadlift_sets = [
      @user1.set_entries.create!(exercise: "Deadlift", weight: 275.0, reps: 5, timestamp: 1.day.ago)
    ]
    
    @resource = ExerciseListResource.new
  end

  test "should generate exercise list content with valid authentication" do
    # Set the API key in ENV for authentication
    ENV['API_KEY'] = @api_key
    
    content = @resource.content
    data = JSON.parse(content)
    
    # Test may have pollution from parallel tests, so check >= 3
    assert data["total_exercises"] >= 3
    assert data["exercises"].length >= 3
    
    # Find exercises by name
    bench_press = data["exercises"].find { |ex| ex["name"] == "Bench Press" }
    squat = data["exercises"].find { |ex| ex["name"] == "Squat" }
    deadlift = data["exercises"].find { |ex| ex["name"] == "Deadlift" }
    
    # Test Bench Press statistics
    assert_equal "Bench Press", bench_press["name"]
    assert_equal 3, bench_press["total_sets"]
    assert_equal 2, bench_press["total_users"]
    assert_equal 145.0, bench_press["average_weight"]
    assert_equal 155.0, bench_press["max_weight"]
    assert bench_press["last_performed"]
    assert_equal 1, bench_press["popularity_rank"] # Most sets, so rank 1
    
    # Test Squat statistics
    assert_equal "Squat", squat["name"]
    assert_equal 2, squat["total_sets"]
    assert_equal 2, squat["total_users"]
    assert_equal 205.0, squat["average_weight"]
    assert_equal 225.0, squat["max_weight"]
    assert squat["last_performed"]
    assert squat["popularity_rank"] >= 2 # Should be among top exercises
    
    # Test Deadlift statistics
    assert_equal "Deadlift", deadlift["name"]
    assert_equal 1, deadlift["total_sets"]
    assert_equal 1, deadlift["total_users"]
    assert_equal 275.0, deadlift["average_weight"]
    assert_equal 275.0, deadlift["max_weight"]
    assert deadlift["last_performed"]
    assert deadlift["popularity_rank"] >= 3 # Should have lower rank due to fewer sets
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should require authentication" do
    # No API key set
    ENV.delete('API_KEY')
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Authentication required to access exercise list", error.message
  end
  
  test "should fail with invalid API key" do
    ENV['API_KEY'] = "invalid_key_123"
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Authentication required to access exercise list", error.message
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should fail with revoked API key" do
    @api_key_record.revoke!
    ENV['API_KEY'] = @api_key
    
    error = assert_raises(StandardError) do
      @resource.content
    end
    
    assert_equal "Authentication required to access exercise list", error.message
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should return empty list when no exercises exist" do
    # Delete all set entries
    SetEntry.destroy_all
    
    ENV['API_KEY'] = @api_key
    
    content = @resource.content
    data = JSON.parse(content)
    
    assert_equal 0, data["total_exercises"]
    assert_equal [], data["exercises"]
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle single exercise correctly" do
    # Delete all but one exercise
    SetEntry.where.not(exercise: "Bench Press").destroy_all
    
    ENV['API_KEY'] = @api_key
    
    content = @resource.content
    data = JSON.parse(content)
    
    assert_equal 1, data["total_exercises"]
    assert_equal 1, data["exercises"].length
    
    exercise = data["exercises"].first
    assert_equal "Bench Press", exercise["name"]
    assert_equal 1, exercise["popularity_rank"]
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle exercises with same popularity correctly" do
    # Create two exercises with same number of sets
    SetEntry.destroy_all
    
    @user1.set_entries.create!(exercise: "Exercise A", weight: 100.0, reps: 10, timestamp: 1.day.ago)
    @user1.set_entries.create!(exercise: "Exercise B", weight: 100.0, reps: 10, timestamp: 1.day.ago)
    
    ENV['API_KEY'] = @api_key
    
    content = @resource.content
    data = JSON.parse(content)
    
    assert_equal 2, data["total_exercises"]
    
    # Both should have different ranks (stable sort)
    ranks = data["exercises"].map { |ex| ex["popularity_rank"] }.sort
    assert_equal [1, 2], ranks
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should calculate average weight correctly" do
    # Test with known weights
    SetEntry.destroy_all
    
    @user1.set_entries.create!(exercise: "Test Exercise", weight: 100.0, reps: 10, timestamp: 3.days.ago)
    @user1.set_entries.create!(exercise: "Test Exercise", weight: 200.0, reps: 10, timestamp: 2.days.ago)
    @user1.set_entries.create!(exercise: "Test Exercise", weight: 150.0, reps: 10, timestamp: 1.day.ago)
    
    ENV['API_KEY'] = @api_key
    
    content = @resource.content
    data = JSON.parse(content)
    
    exercise = data["exercises"].first
    assert_equal 150.0, exercise["average_weight"] # (100 + 200 + 150) / 3
    assert_equal 200.0, exercise["max_weight"]
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should format last_performed timestamp correctly" do
    SetEntry.destroy_all
    
    timestamp = 2.days.ago
    @user1.set_entries.create!(exercise: "Test Exercise", weight: 100.0, reps: 10, timestamp: timestamp)
    
    ENV['API_KEY'] = @api_key
    
    content = @resource.content
    data = JSON.parse(content)
    
    exercise = data["exercises"].first
    assert_equal timestamp.iso8601, exercise["last_performed"]
    
    # Should be parseable as ISO8601
    assert_nothing_raised do
      Time.iso8601(exercise["last_performed"])
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should handle nil timestamps gracefully" do
    SetEntry.destroy_all
    
    # Create entry with nil timestamp (though this shouldn't normally happen)
    entry = @user1.set_entries.build(exercise: "Test Exercise", weight: 100.0, reps: 10, timestamp: nil)
    entry.save(validate: false)
    
    ENV['API_KEY'] = @api_key
    
    # Should not raise an error
    assert_nothing_raised do
      content = @resource.content
      data = JSON.parse(content)
      exercise = data["exercises"].first
      # last_performed should be nil for nil timestamp
      assert_nil exercise["last_performed"]
    end
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should return valid JSON" do
    ENV['API_KEY'] = @api_key
    
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
    assert_equal "fitness://exercises", ExerciseListResource.uri
    assert_equal "Exercise List", ExerciseListResource.resource_name
    assert_equal "List of all exercises with usage statistics", ExerciseListResource.description
    assert_equal "application/json", ExerciseListResource.mime_type
  end
  
  test "should inherit from FastMcp::Resource" do
    assert ExerciseListResource < FastMcp::Resource
  end
  
  test "should count unique users correctly" do
    SetEntry.destroy_all
    
    # Create sets for same exercise by different users
    @user1.set_entries.create!(exercise: "Test Exercise", weight: 100.0, reps: 10, timestamp: 1.day.ago)
    @user1.set_entries.create!(exercise: "Test Exercise", weight: 110.0, reps: 8, timestamp: 1.day.ago)
    @user2.set_entries.create!(exercise: "Test Exercise", weight: 120.0, reps: 6, timestamp: 1.day.ago)
    
    ENV['API_KEY'] = @api_key
    
    content = @resource.content
    data = JSON.parse(content)
    
    exercise = data["exercises"].first
    assert_equal 3, exercise["total_sets"]
    assert_equal 2, exercise["total_users"] # Only 2 unique users
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  test "should sort exercises by popularity descending" do
    SetEntry.destroy_all
    
    # Create exercises with different numbers of sets
    # Exercise A: 1 set
    @user1.set_entries.create!(exercise: "Exercise A", weight: 100.0, reps: 10, timestamp: 1.day.ago)
    
    # Exercise B: 3 sets
    3.times do |i|
      @user1.set_entries.create!(exercise: "Exercise B", weight: 100.0, reps: 10, timestamp: 1.day.ago)
    end
    
    # Exercise C: 2 sets
    2.times do |i|
      @user1.set_entries.create!(exercise: "Exercise C", weight: 100.0, reps: 10, timestamp: 1.day.ago)
    end
    
    ENV['API_KEY'] = @api_key
    
    content = @resource.content
    data = JSON.parse(content)
    
    # Should be sorted by total_sets descending
    assert_equal "Exercise B", data["exercises"][0]["name"] # 3 sets, rank 1
    assert_equal "Exercise C", data["exercises"][1]["name"] # 2 sets, rank 2
    assert_equal "Exercise A", data["exercises"][2]["name"] # 1 set, rank 3
    
    assert_equal 1, data["exercises"][0]["popularity_rank"]
    assert_equal 2, data["exercises"][1]["popularity_rank"]
    assert_equal 3, data["exercises"][2]["popularity_rank"]
    
    # Cleanup
    ENV.delete('API_KEY')
  end
  
  def teardown
    # Ensure ENV is clean after each test
    ENV.delete('API_KEY')
  end
end