#!/usr/bin/env ruby

# Unified MCP Server using fast-mcp gem
ENV['API_KEY'] ||= 'c52fea4b46bcad9f8c692715179dd386'
ENV['RAILS_ENV'] ||= 'development'

# Determine mode from environment or arguments
mode = ENV['MCP_MODE']&.to_sym || :production

# Optimize for STDIO mode
if ARGV[0] == 'stdio'
  mode = :silent
  ENV['RAILS_LOG_LEVEL'] = 'fatal'
end

# Load Rails environment
require_relative 'config/environment'

# Load our unified MCP server configuration
require_relative 'config/mcp_server'

# Create server with appropriate mode
server = FitnessMcp::Server.build(mode: mode)

# Configure additional settings for STDIO mode
if ARGV[0] == 'stdio'
  # Suppress Rails logging completely
  Rails.logger = Logger.new('/dev/null')
  ActiveRecord::Base.logger = nil if defined?(ActiveRecord)
  
  # Optimize database for performance
  if ActiveRecord::Base.connection.adapter_name == 'SQLite'
    ActiveRecord::Base.connection.execute("PRAGMA journal_mode = MEMORY")
    ActiveRecord::Base.connection.execute("PRAGMA synchronous = OFF")
    ActiveRecord::Base.connection.execute("PRAGMA cache_size = 10000")
  end
end

# Start server based on transport type
case ARGV[0]
when 'stdio'
  # Start STDIO transport for Claude Desktop integration
  server.start
when 'http'
  # Start HTTP transport for web integration
  port = ARGV[1] || 8080
  server.start_rack(nil, port: port.to_i)
when 'sse'
  # Start Server-Sent Events transport for real-time updates
  require 'rack'
  require 'puma'
  
  port = ARGV[1] || 8080
  puts "Starting MCP server with HTTP transport on port #{port}"
  server.start_rack(nil, port: port.to_i)
else
  puts "Usage: #{$0} [stdio|http|sse] [port]"
  puts ""
  puts "Transport modes:"
  puts "  stdio - Standard I/O for Claude Desktop (default)"
  puts "  http  - HTTP REST API for web integration"
  puts "  sse   - Server-Sent Events for real-time updates"
  puts ""
  puts "Environment variables:"
  puts "  MCP_MODE - Server mode: production, debug, fast, silent"
  puts "  API_KEY  - Authentication key for API access"
  exit 1
end