require "test_helper"

class SetEntryTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = create_user
    set_entry = user.set_entries.build(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: Time.current
    )
    assert set_entry.valid?
  end

  test "should require user_id" do
    set_entry = SetEntry.new(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: Time.current
    )
    assert_not set_entry.valid?
    assert_includes set_entry.errors[:user], "must exist"
  end

  test "should require exercise" do
    user = create_user
    set_entry = user.set_entries.build(
      weight: 135.0,
      reps: 10,
      timestamp: Time.current
    )
    assert_not set_entry.valid?
    assert_includes set_entry.errors[:exercise], "can't be blank"
  end

  test "should require weight" do
    user = create_user
    set_entry = user.set_entries.build(
      exercise: "Bench Press",
      reps: 10,
      timestamp: Time.current
    )
    assert_not set_entry.valid?
    assert_includes set_entry.errors[:weight], "can't be blank"
  end

  test "should require reps" do
    user = create_user
    set_entry = user.set_entries.build(
      exercise: "Bench Press",
      weight: 135.0,
      timestamp: Time.current
    )
    assert_not set_entry.valid?
    assert_includes set_entry.errors[:reps], "can't be blank"
  end

  test "should require positive weight" do
    user = create_user
    set_entry = user.set_entries.build(
      exercise: "Bench Press",
      weight: -10.0,
      reps: 10,
      timestamp: Time.current
    )
    assert_not set_entry.valid?
    assert_includes set_entry.errors[:weight], "must be greater than 0"
  end

  test "should require positive reps" do
    user = create_user
    set_entry = user.set_entries.build(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 0,
      timestamp: Time.current
    )
    assert_not set_entry.valid?
    assert_includes set_entry.errors[:reps], "must be greater than 0"
  end

  test "should belong to user" do
    user = create_user
    set_entry = user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: Time.current
    )
    assert_equal user, set_entry.user
  end

  test "should set default timestamp if not provided" do
    user = create_user
    set_entry = user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10
    )
    assert_not_nil set_entry.timestamp
    assert_in_delta Time.current, set_entry.timestamp, 1.second
  end

  test "should order by timestamp descending" do
    user = create_user
    old_entry = user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: 2.hours.ago
    )
    new_entry = user.set_entries.create!(
      exercise: "Squat",
      weight: 185.0,
      reps: 8,
      timestamp: 1.hour.ago
    )
    
    entries = user.set_entries.recent
    assert_equal new_entry, entries.first
    assert_equal old_entry, entries.last
  end

  test "should filter by exercise" do
    user = create_user
    bench_entry = user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: Time.current
    )
    squat_entry = user.set_entries.create!(
      exercise: "Squat",
      weight: 185.0,
      reps: 8,
      timestamp: Time.current
    )
    
    bench_entries = user.set_entries.for_exercise("Bench Press")
    assert_includes bench_entries, bench_entry
    assert_not_includes bench_entries, squat_entry
  end
end
