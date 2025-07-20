#!/usr/bin/env ruby

# Ultra-fast MCP server - loads only essential components
ENV['API_KEY'] ||= 'c52fea4b46bcad9f8c692715179dd386'

# Minimal Ruby setup
require 'bundler/setup'
require 'active_record'
require 'sqlite3'
require 'logger'
require 'fast_mcp'

# Configure ActiveRecord directly (skip full Rails)
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'storage/development.sqlite3',
  pool: 5,
  timeout: 5000
)

# CRITICAL: Suppress ALL logging for STDIO mode before loading anything else
if ARGV[0] == 'stdio'
  ActiveRecord::Base.logger = nil
  
  # Redirect STDERR to suppress fast_mcp logs
  $stderr.reopen('/dev/null', 'w')
  
  # Monkey patch FastMcp::Logger to suppress all output
  module FastMcp
    class Logger
      def initialize(*args); end
      def info(*args); end
      def debug(*args); end
      def warn(*args); end
      def error(*args); end
      def log(*args); end
      def add(*args); end
      def <<(*args); end
      def fatal(*args); end
      def unknown(*args); end
      def level=(*args); end
      def level; 0; end
      def progname=(*args); end
      def progname; nil; end
      def formatter=(*args); end
      def formatter; nil; end
      def datetime_format=(*args); end
      def datetime_format; nil; end
      def close; end
      def reopen(*args); end
    end
  end
  
  # Also suppress any puts/print statements
  def puts(*args); end
  def print(*args); end
  def p(*args); end
end

# Load only the model files we need
require_relative 'app/models/application_record'
require_relative 'app/models/user'
require_relative 'app/models/api_key'  
require_relative 'app/models/set_entry'
require_relative 'app/models/workout_assignment'
require_relative 'app/models/mcp_audit_log'

# Load only the tool files we need
require_relative 'app/tools/application_tool'
require_relative 'app/tools/log_set_tool'
require_relative 'app/tools/get_last_set_tool'
require_relative 'app/tools/get_last_sets_tool'
require_relative 'app/tools/get_recent_sets_tool'
require_relative 'app/tools/delete_last_set_tool'
require_relative 'app/tools/assign_workout_tool'

# Load resource files
require_relative 'app/resources/user_stats_resource'
require_relative 'app/resources/workout_history_resource'
require_relative 'app/resources/exercise_list_resource'

# Create MCP server
server = FastMcp::Server.new(
  name: 'fitness-mcp',
  version: '1.0.0'
)

# Register all fitness tools
[LogSetTool, GetLastSetTool, GetLastSetsTool, GetRecentSetsTool, DeleteLastSetTool, AssignWorkoutTool].each do |tool_class|
  server.register_tool(tool_class)
end

# Register all fitness resources
[UserStatsResource, WorkoutHistoryResource, ExerciseListResource].each do |resource_class|
  server.register_resource(resource_class)
end

# Start server based on arguments
case ARGV[0]
when 'stdio'
  server.start
when 'http'
  port = ARGV[1] || 8080
  server.start_rack(nil, port: port.to_i)
else
  puts "Usage: #{$0} [stdio|http] [port]"
  exit 1
end