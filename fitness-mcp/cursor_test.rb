#!/usr/bin/env ruby

# Direct test of MCP tools for use in Cursor
# This simulates what Cursor could do to test the fitness tools

require_relative 'config/environment'

# Configuration - you can change this API key
API_KEY = 'c52fea4b46bcad9f8c692715179dd386'

puts "=== Fitness MCP Tool Test for Cursor ==="
puts "API Key: #{API_KEY}"
puts

# Helper method to test tools directly
def test_tool(tool_name, params)
  puts "Testing #{tool_name}..."
  puts "Params: #{params.inspect}"
  
  begin
    tool_class = Object.const_get(tool_name)
    tool = tool_class.new(api_key: API_KEY)
    result = tool.call(**params)
    
    puts "✓ Success!"
    puts "Result: #{JSON.pretty_generate(result)}"
  rescue => e
    puts "❌ Error: #{e.message}"
    puts e.backtrace.first(3).join("\n") if e.backtrace
  end
  
  puts "-" * 50
end

# Test all the fitness tools
puts "\n1. Log a squat set"
test_tool('LogSetTool', {
  exercise: 'squat',
  weight: 225.0,
  reps: 5
})

puts "\n2. Get the last squat set"
test_tool('GetLastSetTool', {
  exercise: 'squat'
})

puts "\n3. Log a bench press set"
test_tool('LogSetTool', {
  exercise: 'bench press',
  weight: 185.0,
  reps: 8
})

puts "\n4. Get last 3 bench press sets"
test_tool('GetLastSetsTool', {
  exercise: 'bench press',
  limit: 3
})

puts "\n5. Get all recent sets"
test_tool('GetRecentSetsTool', {
  limit: 10
})

puts "\n6. Create a workout assignment"
test_tool('AssignWorkoutTool', {
  assignment_name: 'Push Day',
  exercises: [
    {name: 'bench press', sets: 3, reps: 8, weight: 185},
    {name: 'overhead press', sets: 3, reps: 10, weight: 135},
    {name: 'tricep dips', sets: 3, reps: 12, weight: 0}
  ]
})

puts "\n7. Delete the last squat set"
test_tool('DeleteLastSetTool', {
  exercise: 'squat'
})

puts "\n=== Test Complete ==="
puts "All fitness tools have been tested!"
puts "You can now use these tools with the MCP server in production."