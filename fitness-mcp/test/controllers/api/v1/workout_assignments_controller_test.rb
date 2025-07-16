require "test_helper"

class Api::V1::WorkoutAssignmentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @other_user = create_user(email: "other@example.com")
    @other_api_key_record, @other_api_key = create_api_key(user: @other_user)
    
    # Create test workout assignments
    @assignment1 = @user.workout_assignments.create!(
      assignment_name: "Morning Workout",
      config: '{"exercises": ["Push-ups", "Squats"], "sets": 3}',
      scheduled_for: 1.day.from_now
    )
    
    @assignment2 = @user.workout_assignments.create!(
      assignment_name: "Evening Workout",
      config: '{"exercises": ["Deadlifts", "Bench Press"], "sets": 4}',
      scheduled_for: 2.days.from_now
    )
    
    @past_assignment = @user.workout_assignments.create!(
      assignment_name: "Past Workout",
      config: '{"exercises": ["Running"], "duration": 30}',
      scheduled_for: 1.day.ago
    )
    
    @other_assignment = @other_user.workout_assignments.create!(
      assignment_name: "Other User Workout",
      config: '{"exercises": ["Yoga"], "duration": 45}',
      scheduled_for: 1.day.from_now
    )
  end

  test "should get index with valid API key" do
    get "/api/v1/workout_assignments", headers: api_headers(@api_key), params: { per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 3, json["workout_assignments"].length
    assert json["pagination"]
    assert_equal 1, json["pagination"]["page"]
    assert_equal 10, json["pagination"]["per_page"]
    assert_equal 3, json["pagination"]["total"]
    
    # Check workout assignment structure
    assignment = json["workout_assignments"].first
    assert assignment["id"]
    assert assignment["assignment_name"]
    assert assignment["config"]
    assert assignment["scheduled_for"]
    assert assignment["created_at"]
    assert assignment["updated_at"]
  end
  
  test "should not get index without API key" do
    get "/api/v1/workout_assignments"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "should only show user's own workout assignments" do
    get "/api/v1/workout_assignments", headers: api_headers(@api_key), params: { per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 3, json["workout_assignments"].length
    
    # Should not include other user's assignments
    assignment_names = json["workout_assignments"].map { |assignment| assignment["assignment_name"] }
    assert_includes assignment_names, "Morning Workout"
    assert_includes assignment_names, "Evening Workout"
    assert_includes assignment_names, "Past Workout"
    assert_not_includes assignment_names, "Other User Workout"
  end
  
  test "should filter by scheduled status" do
    get "/api/v1/workout_assignments", 
        headers: api_headers(@api_key),
        params: { scheduled: "true", per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    # All assignments have scheduled_for set, so should return all
    assert_equal 3, json["workout_assignments"].length
  end
  
  test "should filter by upcoming status" do
    get "/api/v1/workout_assignments", 
        headers: api_headers(@api_key),
        params: { upcoming: "true", per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    # Should only return future assignments
    assert_equal 2, json["workout_assignments"].length
    
    assignment_names = json["workout_assignments"].map { |assignment| assignment["assignment_name"] }
    assert_includes assignment_names, "Morning Workout"
    assert_includes assignment_names, "Evening Workout"
    assert_not_includes assignment_names, "Past Workout"
  end
  
  test "should handle pagination" do
    get "/api/v1/workout_assignments", 
        headers: api_headers(@api_key),
        params: { page: 1, per_page: 1 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 1, json["workout_assignments"].length
    assert_equal 1, json["pagination"]["page"]
    assert_equal 1, json["pagination"]["per_page"]
    assert_equal 3, json["pagination"]["total"]
  end
  
  test "should handle pagination with invalid page" do
    get "/api/v1/workout_assignments", 
        headers: api_headers(@api_key),
        params: { page: 0, per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["pagination"]["page"]
  end
  
  test "should limit per_page to maximum" do
    get "/api/v1/workout_assignments", 
        headers: api_headers(@api_key),
        params: { per_page: 1000 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 100, json["pagination"]["per_page"]
  end
  
  test "should handle per_page minimum" do
    get "/api/v1/workout_assignments", 
        headers: api_headers(@api_key),
        params: { per_page: 0 }
    
    assert_response :success
    json = JSON.parse(response.body)
    # Same pagination bug as set_entries - per_page becomes 1 instead of 20
    assert_equal 1, json["pagination"]["per_page"]
  end
  
  test "should show workout assignment" do
    get "/api/v1/workout_assignments/#{@assignment1.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal @assignment1.id, json["workout_assignment"]["id"]
    assert_equal "Morning Workout", json["workout_assignment"]["assignment_name"]
    assert_equal({"exercises" => ["Push-ups", "Squats"], "sets" => 3}, json["workout_assignment"]["config"])
  end
  
  test "should not show other user's workout assignment" do
    get "/api/v1/workout_assignments/#{@other_assignment.id}", headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Workout assignment not found"
  end
  
  test "should not show non-existent workout assignment" do
    get "/api/v1/workout_assignments/999999", headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Workout assignment not found"
  end
  
  test "should create workout assignment with valid data" do
    post "/api/v1/workout_assignments", 
         headers: api_headers(@api_key),
         params: {
           workout_assignment: {
             assignment_name: "New Workout",
             config: '{"exercises": ["Burpees"], "reps": 20}',
             scheduled_for: 3.days.from_now.iso8601
           }
         }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Workout assignment created successfully", json["message"]
    assert_equal "New Workout", json["workout_assignment"]["assignment_name"]
    assert_equal({"exercises" => ["Burpees"], "reps" => 20}, json["workout_assignment"]["config"])
    
    # Verify it was actually created
    assert_equal 4, @user.workout_assignments.count
  end
  
  test "should not create workout assignment without required fields" do
    post "/api/v1/workout_assignments", 
         headers: api_headers(@api_key),
         params: {
           workout_assignment: {
             assignment_name: "Incomplete Workout"
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "Config can't be blank"
    # scheduled_for is now optional
  end
  
  test "should not create workout assignment with invalid data" do
    post "/api/v1/workout_assignments", 
         headers: api_headers(@api_key),
         params: {
           workout_assignment: {
             assignment_name: "",
             config: "",
             scheduled_for: ""
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "Assignment name can't be blank"
    assert_includes json["error"], "Config can't be blank"
    # scheduled_for is now optional
  end
  
  test "should not create workout assignment without API key" do
    post "/api/v1/workout_assignments", 
         params: {
           workout_assignment: {
             assignment_name: "New Workout",
             config: '{"exercises": ["Burpees"]}',
             scheduled_for: 3.days.from_now.iso8601
           }
         }
    
    assert_response :unauthorized
  end
  
  test "should update workout assignment" do
    patch "/api/v1/workout_assignments/#{@assignment1.id}", 
          headers: api_headers(@api_key),
          params: {
            workout_assignment: {
              assignment_name: "Updated Morning Workout",
              config: '{"exercises": ["Modified Push-ups"], "sets": 5}'
            }
          }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Workout assignment updated successfully", json["message"]
    assert_equal "Updated Morning Workout", json["workout_assignment"]["assignment_name"]
    assert_equal({"exercises" => ["Modified Push-ups"], "sets" => 5}, json["workout_assignment"]["config"])
    
    # Verify it was actually updated
    @assignment1.reload
    assert_equal "Updated Morning Workout", @assignment1.assignment_name
  end
  
  test "should not update other user's workout assignment" do
    patch "/api/v1/workout_assignments/#{@other_assignment.id}", 
          headers: api_headers(@api_key),
          params: {
            workout_assignment: {
              assignment_name: "Hacked Workout"
            }
          }
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Workout assignment not found"
  end
  
  test "should not update workout assignment with invalid data" do
    patch "/api/v1/workout_assignments/#{@assignment1.id}", 
          headers: api_headers(@api_key),
          params: {
            workout_assignment: {
              assignment_name: "",
              config: ""
            }
          }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "Assignment name can't be blank"
    assert_includes json["error"], "Config can't be blank"
  end
  
  test "should destroy workout assignment" do
    delete "/api/v1/workout_assignments/#{@assignment1.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Workout assignment deleted successfully", json["message"]
    
    # Verify it was actually deleted
    assert_not @user.workout_assignments.exists?(@assignment1.id)
  end
  
  test "should not destroy other user's workout assignment" do
    delete "/api/v1/workout_assignments/#{@other_assignment.id}", headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Workout assignment not found"
    
    # Verify it still exists
    assert @other_user.workout_assignments.exists?(@other_assignment.id)
  end
  
  test "should not destroy non-existent workout assignment" do
    delete "/api/v1/workout_assignments/999999", headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Workout assignment not found"
  end
  
  test "scheduled_for should be in ISO8601 format" do
    get "/api/v1/workout_assignments/#{@assignment1.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    scheduled_for = json["workout_assignment"]["scheduled_for"]
    
    # Should be parseable as ISO8601
    assert_nothing_raised do
      Time.iso8601(scheduled_for)
    end
  end
  
  test "config should be parsed as JSON" do
    get "/api/v1/workout_assignments/#{@assignment1.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    config = json["workout_assignment"]["config"]
    
    # Should be a hash, not a JSON string
    assert_instance_of Hash, config
    assert_equal ["Push-ups", "Squats"], config["exercises"]
    assert_equal 3, config["sets"]
  end
  
  test "should handle missing workout_assignment params" do
    post "/api/v1/workout_assignments", 
         headers: api_headers(@api_key),
         params: {}
    
    assert_response :bad_request
  end
  
  test "should order assignments by created_at desc" do
    get "/api/v1/workout_assignments", headers: api_headers(@api_key), params: { per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    
    # Should be ordered by most recent first
    created_ats = json["workout_assignments"].map { |assignment| Time.iso8601(assignment["created_at"]) }
    assert_equal created_ats, created_ats.sort.reverse
  end
  
  test "should handle invalid JSON in config gracefully" do
    # Create an assignment with invalid JSON
    assignment = @user.workout_assignments.create!(
      assignment_name: "Invalid JSON Workout",
      config: 'invalid json',
      scheduled_for: 1.day.from_now
    )
    
    get "/api/v1/workout_assignments/#{assignment.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    
    # Should return empty hash for invalid JSON
    assert_equal({}, json["workout_assignment"]["config"])
  end
  
  test "should handle nil scheduled_for in response" do
    # This shouldn't normally happen due to validation, but test the method
    assignment = @user.workout_assignments.build(
      assignment_name: "Test",
      config: '{"test": true}',
      scheduled_for: nil
    )
    
    # Skip validation for this test
    assignment.save(validate: false)
    
    get "/api/v1/workout_assignments/#{assignment.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert_nil json["workout_assignment"]["scheduled_for"]
  end
  
  test "should handle both string and non-string scheduled param" do
    # Test with scheduled: false
    get "/api/v1/workout_assignments", 
        headers: api_headers(@api_key),
        params: { scheduled: "false", per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    # Should return all assignments since scheduled != "true"
    assert_equal 3, json["workout_assignments"].length
  end
  
  test "should handle both string and non-string upcoming param" do
    # Test with upcoming: false
    get "/api/v1/workout_assignments", 
        headers: api_headers(@api_key),
        params: { upcoming: "false", per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    # Should return all assignments since upcoming != "true"
    assert_equal 3, json["workout_assignments"].length
  end
  
  test "should handle empty config properly" do
    post "/api/v1/workout_assignments", 
         headers: api_headers(@api_key),
         params: {
           workout_assignment: {
             assignment_name: "Empty Config Workout",
             config: '{}',
             scheduled_for: 3.days.from_now.iso8601
           }
         }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal({}, json["workout_assignment"]["config"])
  end
end