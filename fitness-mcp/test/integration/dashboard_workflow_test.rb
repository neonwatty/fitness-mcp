require "test_helper"

class DashboardWorkflowTest < ActionDispatch::IntegrationTest
  test "complete user workflow: register, login, create API key, use Quick Actions" do
    # Step 1: Register a new user
    get "/register"
    assert_response :success
    
    post "/register", params: {
      user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    
    # Should redirect to dashboard after successful registration
    assert_redirected_to "/dashboard"
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Welcome, newuser@example.com"
    
    # Step 2: Verify dashboard shows no API keys initially
    assert_select "p", text: "No API keys yet. Create one to get started."
    
    # Step 3: Create an API key via web interface
    post "/api_keys", params: {
      api_key: { name: "My First API Key" }
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key created successfully", json["message"]
    assert json["api_key"]["key"].present?
    
    # Store the API key for testing
    api_key = json["api_key"]["key"]
    
    # Step 4: Go back to dashboard and verify the API key appears
    get "/dashboard"
    assert_response :success
    assert_select "span.font-medium", text: "My First API Key"
    
    # Step 5: Test the Quick Actions - Log a workout set via API
    post "/api/v1/fitness/log_set", params: {
      exercise: "Bench Press",
      weight: 150.0,
      reps: 8
    }, headers: {
      "Authorization" => "Bearer #{api_key}"
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["set"].present?
    assert_equal "Bench Press", json["set"]["exercise"]
    
    # Step 6: Test Get Last Set via API
    get "/api/v1/fitness/get_last_set", params: {
      exercise: "Bench Press"
    }, headers: {
      "Authorization" => "Bearer #{api_key}"
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["set"].present?
    assert_equal "Bench Press", json["set"]["exercise"]
    assert_equal "150.0", json["set"]["weight"]
    assert_equal 8, json["set"]["reps"]
    
    # Step 7: Test Get Last N Sets via API
    get "/api/v1/fitness/get_last_sets", params: {
      exercise: "Bench Press",
      limit: 5
    }, headers: {
      "Authorization" => "Bearer #{api_key}"
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["sets"].present?
    assert_equal 1, json["sets"].length
    assert_equal "Bench Press", json["sets"][0]["exercise"]
    
    # Step 8: Verify dashboard shows the recent activity
    get "/dashboard"
    assert_response :success
    assert_select "h2", text: "Recent Sets"
    # The recent sets should show our logged workout
    assert_select ".bg-gray-50", text: /Bench Press/
    assert_select ".bg-gray-50", text: /8 reps @ 150.0 lbs/
    
    # Step 9: Test API key revocation workflow
    api_key_id = User.find_by(email: "newuser@example.com").api_keys.first.id
    
    patch "/api_keys/#{api_key_id}/revoke"
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key revoked successfully", json["message"]
    
    # Step 10: Verify revoked API key no longer works
    post "/api/v1/fitness/log_set", params: {
      exercise: "Squat",
      weight: 200.0,
      reps: 5
    }, headers: {
      "Authorization" => "Bearer #{api_key}",
    }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end

  test "user can test multiple Quick Actions with same API key" do
    # Setup: Create user and API key
    user = create_user(email: "apitest@example.com", password: "password123")
    api_key_record, raw_key = create_api_key(user: user, name: "Test API Key")
    
    # Login
    post "/login", params: {
      email: "apitest@example.com",
      password: "password123"
    }
    
    # Go to dashboard
    get "/dashboard"
    assert_response :success
    
    # Test 1: Log multiple different exercises
    exercises = [
      { exercise: "Bench Press", weight: 135.0, reps: 10 },
      { exercise: "Squat", weight: 185.0, reps: 8 },
      { exercise: "Deadlift", weight: 225.0, reps: 5 }
    ]
    
    exercises.each do |exercise_data|
      post "/api/v1/fitness/log_set", params: exercise_data, headers: {
        "Authorization" => "Bearer #{raw_key}",
        }
      
      assert_response :success
      json = JSON.parse(response.body)
      assert json["success"]
      assert json["set"].present?
      assert_equal exercise_data[:exercise], json["set"]["exercise"]
    end
    
    # Test 2: Get last set for each exercise
    exercises.each do |exercise_data|
      get "/api/v1/fitness/get_last_set", params: {
        exercise: exercise_data[:exercise]
      }, headers: {
        "Authorization" => "Bearer #{raw_key}"
      }
      
      assert_response :success
      json = JSON.parse(response.body)
      assert json["success"]
      assert json["set"].present?
      assert_equal exercise_data[:exercise], json["set"]["exercise"]
      assert_equal exercise_data[:weight].to_s, json["set"]["weight"]
      assert_equal exercise_data[:reps], json["set"]["reps"]
    end
    
    # Test 3: Get multiple sets for one exercise
    # Log additional sets for bench press
    2.times do |i|
      post "/api/v1/fitness/log_set", params: {
        exercise: "Bench Press",
        weight: 145.0 + (i * 5),
        reps: 8
      }, headers: {
        "Authorization" => "Bearer #{raw_key}",
        }
      
      assert_response :success
    end
    
    # Get last 3 bench press sets
    get "/api/v1/fitness/get_last_sets", params: {
      exercise: "Bench Press",
      limit: 3
    }, headers: {
      "Authorization" => "Bearer #{raw_key}"
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["sets"].present?
    assert_equal 3, json["sets"].length
    # Should be ordered newest first
    assert_equal "150.0", json["sets"][0]["weight"]
    assert_equal "145.0", json["sets"][1]["weight"] 
    assert_equal "135.0", json["sets"][2]["weight"]
  end

  test "Quick Actions gracefully handle errors and invalid input" do
    # Setup user and API key
    user = create_user(email: "errortest@example.com", password: "password123")
    api_key_record, raw_key = create_api_key(user: user, name: "Error Test Key")
    
    # Test invalid exercise data
    post "/api/v1/fitness/log_set", params: {
      exercise: "",
      weight: -10.0,
      reps: 0
    }, headers: {
      "Authorization" => "Bearer #{raw_key}"
    }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_includes json["message"], "Exercise is required"
    
    # Test getting last set for non-existent exercise
    get "/api/v1/fitness/get_last_set", params: {
      exercise: "NonExistent Exercise"
    }, headers: {
      "Authorization" => "Bearer #{raw_key}"
    }
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_includes json["message"], "No sets found"
    
    # Test with invalid API key
    post "/api/v1/fitness/log_set", params: {
      exercise: "Test Exercise",
      weight: 100.0,
      reps: 5
    }, headers: {
      "Authorization" => "Bearer invalid_key_12345"
    }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
end