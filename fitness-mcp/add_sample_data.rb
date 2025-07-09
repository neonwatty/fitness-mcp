#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'

# Find the test user
user = User.find_by(email: 'test@example.com')
if user.nil?
  puts "Test user not found. Run 'rails db:seed' first."
  exit 1
end

# Add sample workout data
puts "Adding sample workout data for #{user.email}..."

# Sample workout data from the past week
sample_sets = [
  # Day 1 - Chest & Triceps
  { exercise: "bench press", weight: 185, reps: 8, timestamp: 6.days.ago },
  { exercise: "bench press", weight: 185, reps: 7, timestamp: 6.days.ago + 5.minutes },
  { exercise: "bench press", weight: 185, reps: 6, timestamp: 6.days.ago + 10.minutes },
  { exercise: "incline dumbbell press", weight: 70, reps: 10, timestamp: 6.days.ago + 20.minutes },
  { exercise: "incline dumbbell press", weight: 70, reps: 9, timestamp: 6.days.ago + 25.minutes },
  { exercise: "tricep dips", weight: 200, reps: 12, timestamp: 6.days.ago + 35.minutes },
  { exercise: "tricep dips", weight: 200, reps: 10, timestamp: 6.days.ago + 40.minutes },
  
  # Day 2 - Back & Biceps
  { exercise: "deadlift", weight: 225, reps: 5, timestamp: 5.days.ago },
  { exercise: "deadlift", weight: 225, reps: 5, timestamp: 5.days.ago + 5.minutes },
  { exercise: "deadlift", weight: 225, reps: 4, timestamp: 5.days.ago + 10.minutes },
  { exercise: "pull-ups", weight: 200, reps: 8, timestamp: 5.days.ago + 20.minutes },
  { exercise: "pull-ups", weight: 200, reps: 7, timestamp: 5.days.ago + 25.minutes },
  { exercise: "barbell rows", weight: 135, reps: 10, timestamp: 5.days.ago + 35.minutes },
  { exercise: "barbell rows", weight: 135, reps: 9, timestamp: 5.days.ago + 40.minutes },
  
  # Day 3 - Legs
  { exercise: "squat", weight: 205, reps: 8, timestamp: 4.days.ago },
  { exercise: "squat", weight: 205, reps: 7, timestamp: 4.days.ago + 5.minutes },
  { exercise: "squat", weight: 205, reps: 6, timestamp: 4.days.ago + 10.minutes },
  { exercise: "leg press", weight: 315, reps: 12, timestamp: 4.days.ago + 20.minutes },
  { exercise: "leg press", weight: 315, reps: 11, timestamp: 4.days.ago + 25.minutes },
  { exercise: "lunges", weight: 25, reps: 10, timestamp: 4.days.ago + 35.minutes },
  
  # Day 4 - Shoulders
  { exercise: "overhead press", weight: 95, reps: 8, timestamp: 3.days.ago },
  { exercise: "overhead press", weight: 95, reps: 7, timestamp: 3.days.ago + 5.minutes },
  { exercise: "overhead press", weight: 95, reps: 6, timestamp: 3.days.ago + 10.minutes },
  { exercise: "lateral raises", weight: 20, reps: 12, timestamp: 3.days.ago + 20.minutes },
  { exercise: "lateral raises", weight: 20, reps: 10, timestamp: 3.days.ago + 25.minutes },
  
  # Day 5 - Arms
  { exercise: "bench press", weight: 185, reps: 8, timestamp: 2.days.ago },
  { exercise: "bench press", weight: 185, reps: 8, timestamp: 2.days.ago + 5.minutes },
  { exercise: "bench press", weight: 185, reps: 7, timestamp: 2.days.ago + 10.minutes },
  { exercise: "bicep curls", weight: 30, reps: 12, timestamp: 2.days.ago + 20.minutes },
  { exercise: "bicep curls", weight: 30, reps: 10, timestamp: 2.days.ago + 25.minutes },
  { exercise: "tricep extensions", weight: 25, reps: 12, timestamp: 2.days.ago + 35.minutes },
  
  # Today - Quick morning workout
  { exercise: "push-ups", weight: 200, reps: 20, timestamp: 2.hours.ago },
  { exercise: "push-ups", weight: 200, reps: 18, timestamp: 2.hours.ago + 3.minutes },
  { exercise: "bodyweight squats", weight: 200, reps: 25, timestamp: 2.hours.ago + 10.minutes },
  { exercise: "bodyweight squats", weight: 200, reps: 22, timestamp: 2.hours.ago + 13.minutes },
]

# Clear existing data for clean demo
puts "Clearing existing workout data..."
user.set_entries.destroy_all

# Add the sample data
sample_sets.each do |set_data|
  user.set_entries.create!(set_data)
end

puts "✅ Added #{sample_sets.length} workout sets!"
puts "📊 Exercises included: #{sample_sets.map { |s| s[:exercise] }.uniq.join(', ')}"
puts "📅 Date range: #{6.days.ago.strftime('%Y-%m-%d')} to #{Date.today.strftime('%Y-%m-%d')}"
puts ""
puts "Ready for MCP testing! 🚀"
puts "Try asking Claude: 'Show me my recent workout history'"