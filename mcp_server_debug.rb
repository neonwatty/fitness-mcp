#!/usr/bin/env ruby

# Debug MCP server - shows detailed logging and status
ENV['API_KEY'] ||= 'c52fea4b46bcad9f8c692715179dd386'

puts "🔧 Debug MCP Server Starting..."
puts "API Key: #{ENV['API_KEY'][0..7]}..."
puts "Args: #{ARGV.inspect}"

# Minimal Ruby setup
require 'bundler/setup'
require 'active_record'
require 'sqlite3'
require 'logger'
require 'fast_mcp'

puts "✅ Loaded Ruby dependencies"

# Configure ActiveRecord directly (skip full Rails)
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'storage/development.sqlite3',
  pool: 5,
  timeout: 5000
)

puts "✅ Connected to database: storage/development.sqlite3"

# Test database
begin
  result = ActiveRecord::Base.connection.execute("SELECT name FROM sqlite_master WHERE type='table'")
  table_count = result.to_a.length
  puts "✅ Database has #{table_count} tables"
rescue => e
  puts "❌ Database error: #{e.message}"
  exit 1
end

# Load only the model files we need
puts "📦 Loading models..."
require_relative 'app/models/application_record'
require_relative 'app/models/user'
require_relative 'app/models/api_key'  
require_relative 'app/models/set_entry'
require_relative 'app/models/workout_assignment'
require_relative 'app/models/mcp_audit_log'

puts "✅ Models loaded"

# Test API key
begin
  api_key_record = ApiKey.find_by_key(ENV['API_KEY'])
  if api_key_record
    puts "✅ API key valid for user: #{api_key_record.user.email}"
  else
    puts "⚠️  API key not found in database"
  end
rescue => e
  puts "❌ API key check failed: #{e.message}"
end

# Load only the tool files we need
puts "🔧 Loading tools..."
require_relative 'app/tools/application_tool'
require_relative 'app/tools/log_set_tool'
require_relative 'app/tools/get_last_set_tool'
require_relative 'app/tools/get_last_sets_tool'
require_relative 'app/tools/get_recent_sets_tool'
require_relative 'app/tools/delete_last_set_tool'
require_relative 'app/tools/assign_workout_tool'

puts "✅ Tools loaded"

# Load resource files
puts "📚 Loading resources..."
require_relative 'app/resources/user_stats_resource'
require_relative 'app/resources/workout_history_resource'
require_relative 'app/resources/exercise_list_resource'

puts "✅ Resources loaded"

# Create MCP server
puts "🚀 Creating MCP server..."
server = FastMcp::Server.new(
  name: 'fitness-mcp',
  version: '1.0.0'
)

puts "✅ MCP server created"

# Register all fitness tools
tool_classes = [LogSetTool, GetLastSetTool, GetLastSetsTool, GetRecentSetsTool, DeleteLastSetTool, AssignWorkoutTool]
puts "🔧 Registering #{tool_classes.length} tools..."

tool_classes.each_with_index do |tool_class, i|
  server.register_tool(tool_class)
  puts "  #{i+1}. ✅ #{tool_class.name}"
end

puts "✅ All tools registered"

# Register all fitness resources
resource_classes = [UserStatsResource, WorkoutHistoryResource, ExerciseListResource]
puts "📚 Registering #{resource_classes.length} resources..."

resource_classes.each_with_index do |resource_class, i|
  server.register_resource(resource_class)
  puts "  #{i+1}. ✅ #{resource_class.name}"
end

puts "✅ All resources registered"
puts "🎯 Server capabilities: #{server.capabilities}"
puts "📋 Number of tools: #{tool_classes.length}"
puts "📚 Number of resources: #{resource_classes.length}"

# Start server based on arguments
puts "🚀 Starting server in #{ARGV[0] || 'unknown'} mode..."

case ARGV[0]
when 'stdio'
  puts "📡 STDIO mode - waiting for JSON-RPC requests..."
  puts "💡 Send a request like: {\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0.0\"}}}"
  puts "---"
  server.start
when 'http'
  port = ARGV[1] || 8080
  puts "🌐 HTTP mode on port #{port}"
  server.start_rack(nil, port: port.to_i)
else
  puts "❌ Usage: #{$0} [stdio|http] [port]"
  exit 1
end