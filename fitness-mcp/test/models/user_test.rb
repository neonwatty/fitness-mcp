require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
  end

  test "should require email" do
    user = User.new(
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should require unique email" do
    create_user(email: "test@example.com")
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "should require password" do
    user = User.new(email: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "should authenticate with correct password" do
    user = create_user
    assert user.authenticate("password123")
    assert_not user.authenticate("wrong_password")
  end

  test "should have many api_keys" do
    user = create_user
    assert_respond_to user, :api_keys
    assert_equal 0, user.api_keys.count
    
    api_key, _ = create_api_key(user: user)
    assert_equal 1, user.api_keys.count
    assert_equal api_key, user.api_keys.first
  end

  test "should have many set_entries" do
    user = create_user
    assert_respond_to user, :set_entries
    assert_equal 0, user.set_entries.count
    
    set_entry = user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: Time.current
    )
    assert_equal 1, user.set_entries.count
    assert_equal set_entry, user.set_entries.first
  end

  test "should have many workout_assignments" do
    user = create_user
    assert_respond_to user, :workout_assignments
    assert_equal 0, user.workout_assignments.count
    
    assignment = user.workout_assignments.create!(
      assignment_name: "Push Day",
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Bench Press", "Shoulder Press"] }.to_json
    )
    assert_equal 1, user.workout_assignments.count
    assert_equal assignment, user.workout_assignments.first
  end

  test "should destroy dependent api_keys when user is destroyed" do
    user = create_user
    create_api_key(user: user)
    
    assert_difference "ApiKey.count", -1 do
      user.destroy
    end
  end

  test "should destroy dependent set_entries when user is destroyed" do
    user = create_user
    user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: Time.current
    )
    
    assert_difference "SetEntry.count", -1 do
      user.destroy
    end
  end

  test "should destroy dependent workout_assignments when user is destroyed" do
    user = create_user
    user.workout_assignments.create!(
      assignment_name: "Push Day",
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Bench Press"] }.to_json
    )
    
    assert_difference "WorkoutAssignment.count", -1 do
      user.destroy
    end
  end
end
