#!/usr/bin/env ruby

# Clean MCP server implementation
ENV['API_KEY'] ||= 'c52fea4b46bcad9f8c692715179dd386'

# Load Rails with minimal logging
require_relative 'config/environment'

# Suppress Rails logging to prevent STDOUT contamination
if ARGV[0] == 'stdio'
  Rails.logger = Logger.new('/tmp/mcp_rails.log')
  Rails.logger.level = Logger::ERROR
  ActiveRecord::Base.logger = nil if defined?(ActiveRecord)
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