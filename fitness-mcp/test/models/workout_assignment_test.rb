require "test_helper"

class WorkoutAssignmentTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = create_user
    assignment = user.workout_assignments.build(
      assignment_name: "Push Day",
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Bench Press", "Shoulder Press"] }.to_json
    )
    assert assignment.valid?
  end

  test "should require user_id" do
    assignment = WorkoutAssignment.new(
      assignment_name: "Push Day",
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Bench Press"] }.to_json
    )
    assert_not assignment.valid?
    assert_includes assignment.errors[:user], "must exist"
  end

  test "should require assignment_name" do
    user = create_user
    assignment = user.workout_assignments.build(
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Bench Press"] }.to_json
    )
    assert_not assignment.valid?
    assert_includes assignment.errors[:assignment_name], "can't be blank"
  end

  test "should require scheduled_for" do
    user = create_user
    assignment = user.workout_assignments.build(
      assignment_name: "Push Day",
      config: { exercises: ["Bench Press"] }.to_json
    )
    assert_not assignment.valid?
    assert_includes assignment.errors[:scheduled_for], "can't be blank"
  end

  test "should belong to user" do
    user = create_user
    assignment = user.workout_assignments.create!(
      assignment_name: "Push Day",
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Bench Press"] }.to_json
    )
    assert_equal user, assignment.user
  end

  test "should parse config as JSON" do
    user = create_user
    config_hash = { exercises: ["Bench Press", "Shoulder Press"], sets: 3, reps: 10 }
    assignment = user.workout_assignments.create!(
      assignment_name: "Push Day",
      scheduled_for: Time.current + 1.day,
      config: config_hash.to_json
    )
    
    parsed_config = JSON.parse(assignment.config)
    assert_equal config_hash.stringify_keys, parsed_config
  end

  test "should order by scheduled_for ascending" do
    user = create_user
    later_assignment = user.workout_assignments.create!(
      assignment_name: "Pull Day",
      scheduled_for: Time.current + 2.days,
      config: { exercises: ["Pull Ups"] }.to_json
    )
    earlier_assignment = user.workout_assignments.create!(
      assignment_name: "Push Day",
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Bench Press"] }.to_json
    )
    
    assignments = user.workout_assignments.upcoming
    assert_equal earlier_assignment, assignments.first
    assert_equal later_assignment, assignments.last
  end

  test "should find assignments for today" do
    user = create_user
    today_assignment = user.workout_assignments.create!(
      assignment_name: "Today's Workout",
      scheduled_for: Time.current.beginning_of_day + 12.hours,
      config: { exercises: ["Bench Press"] }.to_json
    )
    tomorrow_assignment = user.workout_assignments.create!(
      assignment_name: "Tomorrow's Workout",
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Squat"] }.to_json
    )
    
    today_assignments = user.workout_assignments.for_date(Date.current)
    assert_includes today_assignments, today_assignment
    assert_not_includes today_assignments, tomorrow_assignment
  end

  test "should find past assignments" do
    user = create_user
    past_assignment = user.workout_assignments.create!(
      assignment_name: "Past Workout",
      scheduled_for: Time.current - 1.day,
      config: { exercises: ["Deadlift"] }.to_json
    )
    future_assignment = user.workout_assignments.create!(
      assignment_name: "Future Workout",
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Squat"] }.to_json
    )
    
    past_assignments = user.workout_assignments.past
    assert_includes past_assignments, past_assignment
    assert_not_includes past_assignments, future_assignment
  end
end
