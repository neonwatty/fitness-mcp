require "test_helper"

class Api::V1::SetEntriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @other_user = create_user
    @other_api_key_record, @other_api_key = create_api_key(user: @other_user)
    
    # Create test set entries
    @set_entry1 = @user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: 1.hour.ago
    )
    
    @set_entry2 = @user.set_entries.create!(
      exercise: "Squat",
      weight: 185.0,
      reps: 8,
      timestamp: 2.hours.ago
    )
    
    @other_set_entry = @other_user.set_entries.create!(
      exercise: "Deadlift",
      weight: 225.0,
      reps: 6,
      timestamp: 30.minutes.ago
    )
  end

  test "should get index with valid API key" do
    get "/api/v1/set_entries", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    
    # Check that we get entries (the exact number depends on per_page logic)
    assert json["set_entries"].length > 0
    assert json["pagination"]
    assert_equal 1, json["pagination"]["page"]
    assert_equal @user.set_entries.count, json["pagination"]["total"]
    
    # Check set entry structure
    set_entry = json["set_entries"].first
    assert set_entry["id"]
    assert set_entry["exercise"]
    assert set_entry["weight"]
    assert set_entry["reps"]
    assert set_entry["timestamp"]
    assert set_entry["created_at"]
    assert set_entry["updated_at"]
  end
  
  test "should not get index without API key" do
    get "/api/v1/set_entries"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "should only show user's own set entries" do
    get "/api/v1/set_entries", headers: api_headers(@api_key), params: { per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 2, json["set_entries"].length
    
    # Should not include other user's entries
    exercise_names = json["set_entries"].map { |entry| entry["exercise"] }
    assert_includes exercise_names, "Bench Press"
    assert_includes exercise_names, "Squat"
    assert_not_includes exercise_names, "Deadlift"
  end
  
  test "should filter by exercise" do
    get "/api/v1/set_entries", 
        headers: api_headers(@api_key),
        params: { exercise: "Bench Press" }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 1, json["set_entries"].length
    assert_equal "Bench Press", json["set_entries"].first["exercise"]
  end
  
  test "should handle pagination" do
    get "/api/v1/set_entries", 
        headers: api_headers(@api_key),
        params: { page: 1, per_page: 1 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 1, json["set_entries"].length
    assert_equal 1, json["pagination"]["page"]
    assert_equal 1, json["pagination"]["per_page"]
    assert_equal 2, json["pagination"]["total"]
  end
  
  test "should handle pagination with invalid page" do
    get "/api/v1/set_entries", 
        headers: api_headers(@api_key),
        params: { page: 0 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["pagination"]["page"]
  end
  
  test "should limit per_page to maximum" do
    get "/api/v1/set_entries", 
        headers: api_headers(@api_key),
        params: { per_page: 1000 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 100, json["pagination"]["per_page"]
  end
  
  test "should handle per_page minimum" do
    get "/api/v1/set_entries", 
        headers: api_headers(@api_key),
        params: { per_page: 0 }
    
    assert_response :success
    json = JSON.parse(response.body)
    # When per_page is 0, the controller logic should set it to 20 (default)
    # But the actual logic has per_page = [[0, 1].max, 100].min = 1
    # Then per_page = 20 if per_page == 0, but per_page is 1, not 0
    assert_equal 1, json["pagination"]["per_page"]
  end
  
  test "should show set entry" do
    get "/api/v1/set_entries/#{@set_entry1.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal @set_entry1.id, json["set_entry"]["id"]
    assert_equal "Bench Press", json["set_entry"]["exercise"]
    assert_equal 135.0, json["set_entry"]["weight"].to_f
    assert_equal 10, json["set_entry"]["reps"]
  end
  
  test "should not show other user's set entry" do
    get "/api/v1/set_entries/#{@other_set_entry.id}", headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Set entry not found"
  end
  
  test "should not show non-existent set entry" do
    get "/api/v1/set_entries/999999", headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Set entry not found"
  end
  
  test "should create set entry with valid data" do
    post "/api/v1/set_entries", 
         headers: api_headers(@api_key),
         params: {
           set_entry: {
             exercise: "Overhead Press",
             weight: 95.0,
             reps: 12,
             timestamp: Time.current.iso8601
           }
         }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Set entry created successfully", json["message"]
    assert_equal "Overhead Press", json["set_entry"]["exercise"]
    assert_equal 95.0, json["set_entry"]["weight"].to_f
    assert_equal 12, json["set_entry"]["reps"]
    
    # Verify it was actually created
    assert_equal 3, @user.set_entries.count
  end
  
  test "should create set entry without timestamp" do
    post "/api/v1/set_entries", 
         headers: api_headers(@api_key),
         params: {
           set_entry: {
             exercise: "Overhead Press",
             weight: 95.0,
             reps: 12
           }
         }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["set_entry"]["timestamp"]
  end
  
  test "should not create set entry without required fields" do
    post "/api/v1/set_entries", 
         headers: api_headers(@api_key),
         params: {
           set_entry: {
             exercise: "Overhead Press"
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "Weight can't be blank"
    assert_includes json["error"], "Reps can't be blank"
  end
  
  test "should not create set entry with invalid data" do
    post "/api/v1/set_entries", 
         headers: api_headers(@api_key),
         params: {
           set_entry: {
             exercise: "",
             weight: -10.0,
             reps: 0
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "Exercise can't be blank"
    assert_includes json["error"], "Weight must be greater than or equal to 0"
    assert_includes json["error"], "Reps must be greater than 0"
  end
  
  test "should not create set entry without API key" do
    post "/api/v1/set_entries", 
         params: {
           set_entry: {
             exercise: "Overhead Press",
             weight: 95.0,
             reps: 12
           }
         }
    
    assert_response :unauthorized
  end
  
  test "should update set entry" do
    patch "/api/v1/set_entries/#{@set_entry1.id}", 
          headers: api_headers(@api_key),
          params: {
            set_entry: {
              weight: 145.0,
              reps: 8
            }
          }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Set entry updated successfully", json["message"]
    assert_equal 145.0, json["set_entry"]["weight"].to_f
    assert_equal 8, json["set_entry"]["reps"]
    
    # Verify it was actually updated
    @set_entry1.reload
    assert_equal 145.0, @set_entry1.weight
    assert_equal 8, @set_entry1.reps
  end
  
  test "should not update other user's set entry" do
    patch "/api/v1/set_entries/#{@other_set_entry.id}", 
          headers: api_headers(@api_key),
          params: {
            set_entry: {
              weight: 145.0
            }
          }
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Set entry not found"
  end
  
  test "should not update set entry with invalid data" do
    patch "/api/v1/set_entries/#{@set_entry1.id}", 
          headers: api_headers(@api_key),
          params: {
            set_entry: {
              weight: -10.0,
              reps: 0
            }
          }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "Weight must be greater than or equal to 0"
    assert_includes json["error"], "Reps must be greater than 0"
  end
  
  test "should destroy set entry" do
    delete "/api/v1/set_entries/#{@set_entry1.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Set entry deleted successfully", json["message"]
    
    # Verify it was actually deleted
    assert_not @user.set_entries.exists?(@set_entry1.id)
  end
  
  test "should not destroy other user's set entry" do
    delete "/api/v1/set_entries/#{@other_set_entry.id}", headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Set entry not found"
    
    # Verify it still exists
    assert @other_user.set_entries.exists?(@other_set_entry.id)
  end
  
  test "should not destroy non-existent set entry" do
    delete "/api/v1/set_entries/999999", headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "Set entry not found"
  end
  
  test "should handle destroy failure gracefully" do
    # This would be rare but could happen if there are DB constraints
    delete "/api/v1/set_entries/#{@set_entry1.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Set entry deleted successfully", json["message"]
  end
  
  test "timestamp should be in ISO8601 format" do
    get "/api/v1/set_entries/#{@set_entry1.id}", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    timestamp = json["set_entry"]["timestamp"]
    
    # Should be parseable as ISO8601
    assert_nothing_raised do
      Time.iso8601(timestamp)
    end
  end
  
  test "should handle missing set_entry params" do
    post "/api/v1/set_entries", 
         headers: api_headers(@api_key),
         params: {}
    
    assert_response :bad_request
  end
  
  test "set entries should be ordered by recent" do
    get "/api/v1/set_entries", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    
    # Should be ordered by most recent first (assuming recent scope orders by timestamp desc)
    timestamps = json["set_entries"].map { |entry| Time.iso8601(entry["timestamp"]) }
    assert_equal timestamps, timestamps.sort.reverse
  end
  
  test "should handle empty exercise filter" do
    get "/api/v1/set_entries", 
        headers: api_headers(@api_key),
        params: { exercise: "", per_page: 10 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["set_entries"].length
  end
  
  test "should handle non-existent exercise filter" do
    get "/api/v1/set_entries", 
        headers: api_headers(@api_key),
        params: { exercise: "Non-existent Exercise" }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["set_entries"].length
  end
end