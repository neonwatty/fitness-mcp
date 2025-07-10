#!/usr/bin/env ruby

# Minimal MCP server test - no Rails, just fast_mcp
require 'bundler/setup'
require 'fast_mcp'

# Create a minimal test tool
class TestTool < MCP::Tool
  def initialize
    super(
      name: "test",
      description: "Test tool"
    )
  end
  
  def call(args)
    { result: "Test successful", args: args }
  end
end

# Create and start server
server = MCP::Server.new(
  name: 'test-mcp',
  version: '1.0.0'
)

server.register_tool(TestTool)

puts "Starting minimal MCP server..."
server.start