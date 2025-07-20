require "test_helper"

class GetLastSetsToolTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @tool = GetLastSetsTool.new
    
    # Mock the API key for the tool
    @tool.instance_variable_set(:@api_key, @api_key)
    
    # Create test sets with different timestamps
    @bench_sets = []
    10.times do |i|
      @bench_sets << @user.set_entries.create!(
        exercise: "bench press",
        weight: 135.0 + (i * 5),
        reps: 10 - i,
        timestamp: (10 - i).hours.ago
      )
    end
    
    @squat_sets = []
    3.times do |i|
      @squat_sets << @user.set_entries.create!(
        exercise: "squat",
        weight: 185.0 + (i * 10),
        reps: 8 - i,
        timestamp: (3 - i).hours.ago
      )
    end
    
    @deadlift_set = @user.set_entries.create!(
      exercise: "deadlift",
      weight: 225.0,
      reps: 5,
      timestamp: 2.hours.ago
    )
  end

  test "should return last 5 sets by default" do
    result = @tool.call(exercise: "bench press")
    
    assert result[:success]
    assert_equal 5, result[:count]
    assert_equal 5, result[:set_entries].length
    assert_includes result[:message], "Found 5 recent sets for bench press"
    
    # Check that sets are ordered by timestamp descending (most recent first)
    weights = result[:set_entries].map { |set| set[:weight] }
    expected_weights = [180.0, 175.0, 170.0, 165.0, 160.0] # Last 5 created (i=9,8,7,6,5)
    assert_equal expected_weights, weights
    
    # Verify structure of each set entry
    set_entry = result[:set_entries].first
    assert set_entry[:id]
    assert_equal "bench press", set_entry[:exercise]
    assert set_entry[:weight].is_a?(Float)
    assert set_entry[:reps].is_a?(Integer)
    assert set_entry[:timestamp]
    
    # Verify timestamp is ISO8601 format
    assert_nothing_raised do
      Time.iso8601(set_entry[:timestamp])
    end
  end
  
  test "should respect custom limit parameter" do
    result = @tool.call(exercise: "bench press", limit: 3)
    
    assert result[:success]
    assert_equal 3, result[:count]
    assert_equal 3, result[:set_entries].length
    assert_includes result[:message], "Found 3 recent sets for bench press"
    
    # Should return the 3 most recent sets
    weights = result[:set_entries].map { |set| set[:weight] }
    expected_weights = [180.0, 175.0, 170.0] # i=9,8,7
    assert_equal expected_weights, weights
  end
  
  test "should handle limit of 1" do
    result = @tool.call(exercise: "bench press", limit: 1)
    
    assert result[:success]
    assert_equal 1, result[:count]
    assert_equal 1, result[:set_entries].length
    
    # Should return only the most recent set
    set_entry = result[:set_entries].first
    assert_equal 180.0, set_entry[:weight] # i=9: 135 + (9*5) = 180
    assert_equal 1, set_entry[:reps] # reps = 10 - 9 = 1
  end
  
  test "should enforce maximum limit of 20" do
    result = @tool.call(exercise: "bench press", limit: 50)
    
    assert result[:success]
    # Should cap at available sets (10) since that's less than 20
    assert_equal 10, result[:count]
    assert_equal 10, result[:set_entries].length
  end
  
  test "should enforce minimum limit of 1" do
    result = @tool.call(exercise: "bench press", limit: 0)
    
    assert result[:success]
    # Should default to 1 when 0 is provided
    assert_equal 1, result[:count]
    assert_equal 1, result[:set_entries].length
  end
  
  test "should handle negative limit" do
    result = @tool.call(exercise: "bench press", limit: -5)
    
    assert result[:success]
    # Should default to 1 when negative limit is provided
    assert_equal 1, result[:count]
    assert_equal 1, result[:set_entries].length
  end
  
  test "should handle exercise with fewer sets than limit" do
    result = @tool.call(exercise: "squat", limit: 10)
    
    assert result[:success]
    assert_equal 3, result[:count] # Only 3 squat sets exist
    assert_equal 3, result[:set_entries].length
    assert_includes result[:message], "Found 3 recent sets for squat"
    
    # Verify all squat sets are returned in correct order
    weights = result[:set_entries].map { |set| set[:weight] }
    expected_weights = [205.0, 195.0, 185.0] # Most recent to oldest
    assert_equal expected_weights, weights
  end
  
  test "should handle single set for exercise" do
    result = @tool.call(exercise: "deadlift")
    
    assert result[:success]
    assert_equal 1, result[:count]
    assert_equal 1, result[:set_entries].length
    assert_includes result[:message], "Found 1 recent sets for deadlift"
    
    set_entry = result[:set_entries].first
    assert_equal "deadlift", set_entry[:exercise]
    assert_equal 225.0, set_entry[:weight]
    assert_equal 5, set_entry[:reps]
  end
  
  test "should handle exercise name case insensitivity" do
    result = @tool.call(exercise: "BENCH PRESS")
    
    assert result[:success]
    assert_equal 5, result[:count]
    result[:set_entries].each do |set|
      assert_equal "bench press", set[:exercise]
    end
  end
  
  test "should handle exercise name with extra whitespace" do
    result = @tool.call(exercise: "  bench press  ")
    
    assert result[:success]
    assert_equal 5, result[:count]
    result[:set_entries].each do |set|
      assert_equal "bench press", set[:exercise]
    end
  end
  
  test "should return error for non-existent exercise" do
    result = @tool.call(exercise: "non-existent exercise")
    
    assert_not result[:success]
    assert_equal "No sets found for non-existent exercise", result[:message]
    assert_nil result[:count]
    assert_nil result[:set_entries]
  end
  
  test "should handle empty exercise name" do
    result = @tool.call(exercise: "")
    
    assert_not result[:success]
    assert_equal "No sets found for ", result[:message]
  end
  
  test "should handle exercise name with only whitespace" do
    result = @tool.call(exercise: "   ")
    
    assert_not result[:success]
    assert_equal "No sets found for    ", result[:message]
  end
  
  test "should preserve timestamp order" do
    result = @tool.call(exercise: "bench press", limit: 10)
    
    assert result[:success]
    
    # Verify timestamps are in descending order (most recent first)
    timestamps = result[:set_entries].map { |set| Time.iso8601(set[:timestamp]) }
    sorted_timestamps = timestamps.sort.reverse
    assert_equal sorted_timestamps, timestamps
  end
  
  test "should handle exercises with special characters" do
    @user.set_entries.create!(exercise: "t-bar row", weight: 90.0, reps: 10, timestamp: 1.hour.ago)
    @user.set_entries.create!(exercise: "21's bicep curl", weight: 45.0, reps: 21, timestamp: 30.minutes.ago)
    
    result1 = @tool.call(exercise: "t-bar row")
    assert result1[:success]
    assert_equal 1, result1[:count]
    assert_equal "t-bar row", result1[:set_entries].first[:exercise]
    
    result2 = @tool.call(exercise: "21's bicep curl")
    assert result2[:success]
    assert_equal 1, result2[:count]
    assert_equal "21's bicep curl", result2[:set_entries].first[:exercise]
  end
  
  test "should handle decimal weights correctly" do
    @user.set_entries.create!(exercise: "light exercise", weight: 12.5, reps: 15, timestamp: 1.hour.ago)
    
    result = @tool.call(exercise: "light exercise")
    
    assert result[:success]
    assert_equal 1, result[:count]
    assert_equal 12.5, result[:set_entries].first[:weight]
  end
  
  test "should convert integer weights to float" do
    @user.set_entries.create!(exercise: "integer exercise", weight: 100, reps: 10, timestamp: 1.hour.ago)
    
    result = @tool.call(exercise: "integer exercise")
    
    assert result[:success]
    assert_equal 100.0, result[:set_entries].first[:weight]
    assert result[:set_entries].first[:weight].is_a?(Float)
  end
  
  test "should include all required fields in set entries" do
    result = @tool.call(exercise: "bench press", limit: 1)
    
    assert result[:success]
    
    set_entry = result[:set_entries].first
    required_fields = [:id, :exercise, :weight, :reps, :timestamp]
    
    required_fields.each do |field|
      assert set_entry.key?(field), "Missing field: #{field}"
      assert_not_nil set_entry[field], "Field #{field} is nil"
    end
    
    # Check data types
    assert set_entry[:id].is_a?(Integer)
    assert set_entry[:exercise].is_a?(String)
    assert set_entry[:weight].is_a?(Float)
    assert set_entry[:reps].is_a?(Integer)
    assert set_entry[:timestamp].is_a?(String)
  end
  
  test "should handle exercise normalization consistently" do
    # Create sets with different capitalizations
    @user.set_entries.create!(exercise: "barbell row", weight: 95.0, reps: 8, timestamp: 2.hours.ago)
    @user.set_entries.create!(exercise: "barbell row", weight: 100.0, reps: 8, timestamp: 1.hour.ago)
    
    result = @tool.call(exercise: "Barbell Row")
    
    assert result[:success]
    assert_equal 2, result[:count]
    result[:set_entries].each do |set|
      assert_equal "barbell row", set[:exercise]
    end
    
    # Verify proper ordering (most recent first)
    weights = result[:set_entries].map { |set| set[:weight] }
    assert_equal [100.0, 95.0], weights
  end
  
  test "should require authentication" do
    @tool.instance_variable_set(:@api_key, nil)
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(exercise: "bench press")
    end
  end
  
  test "should require valid API key" do
    @tool.instance_variable_set(:@api_key, "invalid_key")
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(exercise: "bench press")
    end
  end
  
  test "should not work with revoked API key" do
    @api_key_record.revoke!
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(exercise: "bench press")
    end
  end
  
  test "should only return sets for current user" do
    # Create another user with sets
    other_user = create_user
    other_user.set_entries.create!(exercise: "bench press", weight: 200.0, reps: 5, timestamp: 30.minutes.ago)
    
    result = @tool.call(exercise: "bench press")
    
    assert result[:success]
    # Should only return current user's sets, not other user's
    result[:set_entries].each do |set|
      # Verify weight is not 200.0 (which belongs to other user)
      assert_not_equal 200.0, set[:weight]
    end
    
    # Should return expected number of sets for current user
    assert_equal 5, result[:count] # Default limit
  end
  
  test "should handle limit parameter edge cases" do
    # Test various edge cases for limit parameter
    test_cases = [
      { limit: 0, expected_count: 1 },      # Should default to 1
      { limit: -1, expected_count: 1 },     # Should default to 1
      { limit: 1, expected_count: 1 },      # Should respect 1
      { limit: 20, expected_count: 10 },    # Should cap at available sets (10)
      { limit: 21, expected_count: 10 },    # Should cap at maximum 20, but available is 10
      { limit: 100, expected_count: 10 }    # Should cap at maximum 20, but available is 10
    ]
    
    test_cases.each do |test_case|
      result = @tool.call(exercise: "bench press", limit: test_case[:limit])
      assert result[:success], "Failed for limit: #{test_case[:limit]}"
      assert_equal test_case[:expected_count], result[:count], "Wrong count for limit: #{test_case[:limit]}"
    end
  end
  
  test "should handle string limit parameter" do
    # Test string limit (should be converted to integer)
    result = @tool.call(exercise: "bench press", limit: "3")
    
    assert result[:success]
    assert_equal 3, result[:count]
  end
  
  test "should provide accurate count in response" do
    result = @tool.call(exercise: "bench press", limit: 7)
    
    assert result[:success]
    assert_equal result[:count], result[:set_entries].length
    assert_equal 7, result[:count]
    assert_includes result[:message], "Found 7 recent sets"
  end
  
  test "should handle exercises with mixed case in database" do
    # Create sets with different cases in the database (shouldn't happen in real usage)
    @user.set_entries.create!(exercise: "mixed case", weight: 80.0, reps: 12, timestamp: 1.hour.ago)
    
    # Query should still work with normalized input
    result = @tool.call(exercise: "Mixed Case")
    
    assert result[:success]
    assert_equal 1, result[:count]
    assert_equal "mixed case", result[:set_entries].first[:exercise]
  end
  
  test "should handle complex exercise scenarios" do
    # Create exercises with similar names
    @user.set_entries.create!(exercise: "incline bench press", weight: 115.0, reps: 8, timestamp: 1.hour.ago)
    @user.set_entries.create!(exercise: "decline bench press", weight: 125.0, reps: 10, timestamp: 45.minutes.ago)
    @user.set_entries.create!(exercise: "dumbbell bench press", weight: 70.0, reps: 12, timestamp: 30.minutes.ago)
    
    # Query for specific exercise should only return that exercise
    result = @tool.call(exercise: "incline bench press")
    
    assert result[:success]
    assert_equal 1, result[:count]
    assert_equal "incline bench press", result[:set_entries].first[:exercise]
    assert_equal 115.0, result[:set_entries].first[:weight]
  end
  
  test "should handle user with no sets" do
    user_no_sets = create_user
    api_key_record, api_key = create_api_key(user: user_no_sets)
    tool = GetLastSetsTool.new
    tool.instance_variable_set(:@api_key, api_key)
    
    result = tool.call(exercise: "any exercise")
    
    assert_not result[:success]
    assert_equal "No sets found for any exercise", result[:message]
  end
  
  test "should validate ISO8601 timestamp format" do
    result = @tool.call(exercise: "bench press", limit: 1)
    
    assert result[:success]
    
    timestamp = result[:set_entries].first[:timestamp]
    parsed_time = nil
    
    assert_nothing_raised do
      parsed_time = Time.iso8601(timestamp)
    end
    
    # Verify the parsed time matches the original set timestamp
    original_set = @bench_sets.last # Most recent
    assert_equal original_set.timestamp.to_i, parsed_time.to_i
  end
end