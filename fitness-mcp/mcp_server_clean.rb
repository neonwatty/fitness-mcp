#!/usr/bin/env ruby

# Clean MCP server implementation
ENV['API_KEY'] ||= 'c52fea4b46bcad9f8c692715179dd386'
ENV['RAILS_ENV'] ||= 'development'

# Skip Rails initialization for faster startup in STDIO mode
if ARGV[0] == 'stdio'
  # Minimal Rails loading for MCP
  ENV['RAILS_LOG_LEVEL'] = 'error'
end

# Load Rails with minimal logging
require_relative 'config/environment'

# Suppress all Rails logging for STDIO mode
if ARGV[0] == 'stdio'
  Rails.logger = Logger.new('/dev/null')
  Rails.logger.level = Logger::FATAL
  ActiveRecord::Base.logger = nil if defined?(ActiveRecord)
  
  # Minimize ActiveRecord overhead
  ActiveRecord::Base.connection.execute("PRAGMA journal_mode = MEMORY") if ActiveRecord::Base.connection.adapter_name == 'SQLite'
end

require 'fast_mcp'

# Create MCP server with default logger (it handles STDIO properly)
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