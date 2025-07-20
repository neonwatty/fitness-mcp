#!/usr/bin/env ruby

require_relative 'config/environment'
require 'json'

# Interactive chat interface for testing the MCP server
class MCPChatInterface
  def initialize(api_key)
    @api_key = api_key
    @tools = {
      'log_set' => LogSetTool,
      'get_last_set' => GetLastSetTool,
      'get_last_sets' => GetLastSetsTool,
      'get_recent_sets' => GetRecentSetsTool,
      'delete_last_set' => DeleteLastSetTool,
      'assign_workout' => AssignWorkoutTool
    }
  end

  def start
    puts "🏋️  Fitness MCP Server Chat Interface"
    puts "=" * 50
    puts "You can chat with the fitness MCP server using natural language."
    puts "Type 'help' for available commands or 'quit' to exit."
    puts

    loop do
      print "You: "
      input = gets.chomp.strip
      
      case input.downcase
      when 'quit', 'exit', 'q'
        puts "Goodbye! 👋"
        break
      when 'help', 'h'
        show_help
      when 'tools'
        show_tools
      else
        process_message(input)
      end
      puts
    end
  end

  private

  def show_help
    puts <<~HELP
      Available commands:
      - help/h: Show this help
      - tools: List all available fitness tools
      - quit/exit/q: Exit the chat
      
      You can also use natural language like:
      - "Log 5 reps of squats at 225 lbs"
      - "What was my last bench press?"
      - "Show me my recent deadlift sets"
      - "Delete my last squat set"
      - "Create a workout for tomorrow"
      - "Show all my recent workouts"
    HELP
  end

  def show_tools
    puts "Available fitness tools:"
    @tools.each do |name, tool_class|
      puts "- #{name}: #{tool_class.description}"
    end
  end

  def process_message(message)
    puts "MCP Server: Processing your request..."
    
    # Simple pattern matching for common requests
    case message.downcase
    when /log.*(\d+).*reps?.*of\s+([^,]+?)\s+at\s+(\d+(?:\.\d+)?)\s*(?:lbs?|pounds?|kg)?/i
      reps = $1.to_i
      exercise = $2.strip
      weight = $3.to_f
      log_set(exercise, weight, reps)
      
    when /(?:what|show).*(?:was|is).*(?:my\s+)?last\s+([a-z\s]+?)(?:\?|$)/i
      exercise = $1.strip
      get_last_set(exercise)
      
    when /(?:show|get).*(?:my\s+)?last\s+(\d+)\s+([a-z\s]+?)(?:\s+sets?)?(?:\?|$)/i
      limit = $1.to_i
      exercise = $2.strip
      get_last_sets(exercise, limit)
      
    when /(?:show|get).*(?:my\s+)?recent.*(?:sets?|workouts?)/i
      get_recent_sets
      
    when /delete.*(?:my\s+)?last\s+([a-z\s]+?)(?:\s+set)?(?:\?|$)/i
      exercise = $1.strip
      delete_last_set(exercise)
      
    when /(?:create|assign|plan).*workout/i
      create_workout_interactive
      
    else
      puts "I'm not sure how to help with that. Type 'help' for examples of what I can do."
    end
  end

  def log_set(exercise, weight, reps)
    tool = LogSetTool.new(api_key: @api_key)
    result = tool.call(exercise: exercise, weight: weight, reps: reps)
    
    if result[:success]
      puts "✅ #{result[:message]}"
    else
      puts "❌ Error: #{result[:error]}"
    end
  end

  def get_last_set(exercise)
    tool = GetLastSetTool.new(api_key: @api_key)
    result = tool.call(exercise: exercise)
    
    if result[:success]
      puts "📊 #{result[:message]}"
    else
      puts "❌ Error: #{result[:error] || 'Unknown error occurred'}"
    end
  rescue => e
    puts "❌ Error: #{e.message}"
  end

  def get_last_sets(exercise, limit)
    tool = GetLastSetsTool.new(api_key: @api_key)
    result = tool.call(exercise: exercise, limit: limit)
    
    if result[:success]
      puts "📊 #{result[:message]}"
      result[:set_entries].each_with_index do |set, i|
        puts "  #{i+1}. #{set[:reps]} reps at #{set[:weight]} lbs (#{set[:timestamp]})"
      end
    else
      puts "❌ Error: #{result[:error] || 'Unknown error occurred'}"
    end
  rescue => e
    puts "❌ Error: #{e.message}"
  end

  def get_recent_sets(limit = 10)
    tool = GetRecentSetsTool.new(api_key: @api_key)
    result = tool.call(limit: limit)
    
    if result[:success]
      puts "📊 #{result[:message]}"
      result[:set_entries].each_with_index do |set, i|
        puts "  #{i+1}. #{set[:exercise]}: #{set[:reps]} reps at #{set[:weight]} lbs (#{set[:timestamp]})"
      end
    else
      puts "❌ Error: #{result[:error]}"
    end
  end

  def delete_last_set(exercise)
    tool = DeleteLastSetTool.new(api_key: @api_key)
    result = tool.call(exercise: exercise)
    
    if result[:success]
      puts "🗑️  #{result[:message]}"
    else
      puts "❌ Error: #{result[:error] || 'Unknown error occurred'}"
    end
  rescue => e
    puts "❌ Error: #{e.message}"
  end

  def create_workout_interactive
    puts "Let's create a workout assignment!"
    print "Workout name: "
    name = gets.chomp
    
    puts "Enter exercises (type 'done' when finished):"
    exercises = []
    
    loop do
      print "Exercise name (or 'done'): "
      exercise_name = gets.chomp
      break if exercise_name.downcase == 'done'
      
      print "Sets: "
      sets = gets.chomp.to_i
      
      print "Reps: "
      reps = gets.chomp.to_i
      
      print "Weight: "
      weight = gets.chomp.to_f
      
      exercises << {
        name: exercise_name,
        sets: sets,
        reps: reps,
        weight: weight
      }
      
      puts "Added: #{sets} sets of #{reps} reps #{exercise_name} at #{weight} lbs"
    end
    
    if exercises.empty?
      puts "No exercises added. Workout not created."
      return
    end
    
    tool = AssignWorkoutTool.new(api_key: @api_key)
    result = tool.call(assignment_name: name, exercises: exercises)
    
    if result[:success]
      puts "💪 #{result[:message]}"
      puts "Exercises:"
      result[:workout_assignment][:exercises].each do |ex|
        puts "  - #{ex[:sets]} sets of #{ex[:reps]} reps #{ex[:name]} at #{ex[:weight]} lbs"
      end
    else
      puts "❌ Error: #{result[:error]}"
    end
  end

  def get_weight_input(exercise)
    print "Weight for #{exercise} (lbs): "
    gets.chomp.to_f
  end
end

# Start the chat interface
if __FILE__ == $0
  API_KEY = 'c52fea4b46bcad9f8c692715179dd386'
  
  # Verify API key exists
  api_key_record = ApiKey.find_by_key(API_KEY)
  unless api_key_record
    puts "❌ API key not found! Please run create_test_api_key.rb first."
    exit 1
  end
  
  puts "✅ Connected as: #{api_key_record.user.email}"
  puts
  
  chat = MCPChatInterface.new(API_KEY)
  chat.start
end