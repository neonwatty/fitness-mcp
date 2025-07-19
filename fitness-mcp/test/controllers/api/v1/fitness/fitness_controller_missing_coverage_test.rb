require 'test_helper'

class Api::V1::Fitness::FitnessControllerMissingCoverageTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @headers = { 'Authorization' => "Bearer #{@api_key}" }
  end
  
  test "delete_last_set should delete the most recent set" do
    # Create some sets
    set1 = @user.set_entries.create!(exercise: "Bench Press", weight: 100, reps: 10, timestamp: 2.hours.ago)
    set2 = @user.set_entries.create!(exercise: "Squat", weight: 150, reps: 8, timestamp: 1.hour.ago)
    
    assert_difference '@user.set_entries.count', -1 do
      delete "/api/v1/fitness/delete_last_set", headers: @headers
    end
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Last set deleted successfully", json["message"]
    
    # Verify the most recent set was deleted
    assert_not @user.set_entries.exists?(set2.id)
    assert @user.set_entries.exists?(set1.id)
  end
  
  test "delete_last_set should return not_found when no sets exist" do
    assert_equal 0, @user.set_entries.count
    
    delete "/api/v1/fitness/delete_last_set", headers: @headers
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "No sets found to delete", json["message"]
  end
  
  test "assign_workout should create a new workout assignment" do
    assert_difference '@user.workout_assignments.count', 1 do
      post "/api/v1/fitness/assign_workout", 
        params: {
          assignment_name: "Upper Body Day",
          scheduled_for: Date.tomorrow,
          config: {
            exercises: [
              { name: "Bench Press", sets: 3, reps: 10 },
              { name: "Pull-ups", sets: 3, reps: 8 }
            ]
          }
        },
        headers: @headers
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Workout assigned successfully", json["message"]
    assert json["assignment"]["id"]
    assert_equal "Upper Body Day", json["assignment"]["assignment_name"]
  end
  
  test "assign_workout should fail without required parameters" do
    post "/api/v1/fitness/assign_workout", 
      params: { assignment_name: "Test" },
      headers: @headers
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Scheduled for is required", json["message"]
  end
  
  test "assign_workout should fail without config" do
    post "/api/v1/fitness/assign_workout", 
      params: { 
        assignment_name: "Test",
        scheduled_for: Date.tomorrow
      },
      headers: @headers
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Config is required", json["message"]
  end
  
  test "assign_workout should fail without assignment_name" do
    post "/api/v1/fitness/assign_workout", 
      params: { 
        scheduled_for: Date.tomorrow,
        config: { exercises: [] }
      },
      headers: @headers
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Assignment name is required", json["message"]
  end
end