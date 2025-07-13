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

# Suppress all logging for STDIO mode
if ARGV[0] == 'stdio'
  ActiveRecord::Base.logger = nil
  
  # Redirect STDERR to suppress fast_mcp logs
  $stderr.reopen('/dev/null', 'w')
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

# Create MCP server
server = MCP::Server.new(
  name: 'fitness-mcp',
  version: '1.0.0'
)

# Register all fitness tools
[LogSetTool, GetLastSetTool, GetLastSetsTool, GetRecentSetsTool, DeleteLastSetTool, AssignWorkoutTool].each do |tool_class|
  server.register_tool(tool_class)
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