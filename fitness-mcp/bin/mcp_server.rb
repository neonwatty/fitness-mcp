#!/usr/bin/env ruby

# Load Rails environment
require_relative '../config/environment'
require 'fast_mcp'

# Create MCP server
server = MCP::Server.new(
  name: 'fitness-mcp',
  version: '1.0.0',
  logger: MCP::Logger.new
)

# Register tools with enhanced API key support
# Note: These tools now support dynamic API key injection via constructor
server.register_tool(LogSetTool)
server.register_tool(GetLastSetTool)
server.register_tool(GetLastSetsTool)
server.register_tool(GetRecentSetsTool)
server.register_tool(DeleteLastSetTool)
server.register_tool(AssignWorkoutTool)

# Start server based on arguments
case ARGV[0]
when 'stdio'
  server.start
when 'http'
  port = ARGV[1] || 8080
  server.start_rack(nil, port: port.to_i)
else
  puts "Usage: #{$0} [stdio|http] [port]"
  puts "  stdio: Start STDIO transport"
  puts "  http [port]: Start HTTP transport on port (default: 8080)"
  exit 1
end