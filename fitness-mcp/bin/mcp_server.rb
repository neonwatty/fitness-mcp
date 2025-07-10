#!/usr/bin/env ruby

# For STDIO mode, completely suppress all logging to avoid JSON-RPC interference
if ARGV[0] == 'stdio'
  # Redirect STDOUT and STDERR to /dev/null during Rails loading
  $stdout.sync = true
  $stderr.sync = true
  
  # Capture the original STDOUT
  original_stdout = $stdout.dup
  
  # Redirect all output to /dev/null during Rails initialization
  null_file = File.open('/dev/null', 'w')
  $stdout.reopen(null_file)
  $stderr.reopen(null_file)
end

# Load Rails environment
require_relative '../config/environment'
require 'fast_mcp'

# For STDIO mode, restore STDOUT and configure minimal logging
if ARGV[0] == 'stdio'
  # Restore STDOUT for JSON-RPC communication
  $stdout.reopen(original_stdout)
  
  # Keep STDERR redirected to /dev/null
  Rails.logger = Logger.new('/dev/null')
  
  # Suppress all Active Record logging
  ActiveRecord::Base.logger = nil if defined?(ActiveRecord)
  
  # Suppress other Rails loggers
  ActionController::Base.logger = nil if defined?(ActionController)
  ActionView::Base.logger = nil if defined?(ActionView)
  
  # Close the null file
  null_file.close
  
  # CRITICAL: Suppress MCP's default logger output to STDOUT
  # We need to monkey-patch the logger to prevent it from writing to STDOUT
  require 'logger'
  module MCP
    class Logger
      def initialize(*args)
        @logger = ::Logger.new('/dev/null')
      end
      
      # Forward all logger methods to the null logger
      def method_missing(method_name, *args, &block)
        if @logger.respond_to?(method_name)
          @logger.send(method_name, *args, &block)
        else
          # For any unknown methods, just do nothing
          nil
        end
      end
      
      def respond_to_missing?(method_name, include_private = false)
        @logger.respond_to?(method_name, include_private) || super
      end
      
      # Add specific methods that fast_mcp might expect
      def set_client_initialized(*args)
        # Do nothing - this is just to suppress output
      end
      
      def debug(*args); end
      def info(*args); end
      def warn(*args); end
      def error(*args); end
      def fatal(*args); end
    end
  end
end

# Create MCP server with proper logger and error handling
class FitnessMCPServer < MCP::Server
  def handle_request(request)
    super
  rescue => e
    # Ensure we always have a valid ID in error responses
    id = request['id'] || 0  # Default to 0 if ID is missing
    {
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => {
        "code" => -32603,
        "message" => "Internal error: #{e.message}"
      }
    }
  end
end

server = FitnessMCPServer.new(
  name: 'fitness-mcp',
  version: '1.0.0'
)

# Create tool instances with API key from environment
api_key = ENV['API_KEY']

# Debug output to file
if ARGV[0] == 'stdio'
  File.open('/tmp/mcp_debug.log', 'a') do |f|
    f.puts "[#{Time.now}] Starting tool registration with API key: #{api_key.inspect}"
  end
end

# Register tools - fast_mcp expects classes, not instances
# The API key will be passed via ENV['API_KEY']
begin
  [LogSetTool, GetLastSetTool, GetLastSetsTool, GetRecentSetsTool, DeleteLastSetTool, AssignWorkoutTool].each do |tool_class|
    if ARGV[0] == 'stdio'
      File.open('/tmp/mcp_debug.log', 'a') do |f|
        f.puts "[#{Time.now}] Registering #{tool_class.name}"
      end
    end
    server.register_tool(tool_class)
  end
rescue => e
  if ARGV[0] == 'stdio'
    File.open('/tmp/mcp_debug.log', 'a') do |f|
      f.puts "[#{Time.now}] Error during tool registration: #{e.message}"
      f.puts e.backtrace.join("\n")
    end
  end
  raise
end

# Start server based on arguments
begin
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
rescue => e
  if ARGV[0] == 'stdio'
    # For STDIO mode, write error to a log file since STDERR is redirected
    File.open('/tmp/mcp_server_error.log', 'a') do |f|
      f.puts "[#{Time.now}] MCP Server Error: #{e.message}"
      f.puts e.backtrace.join("\n")
      f.puts "---"
    end
  else
    puts "Error: #{e.message}"
    puts e.backtrace.join("\n")
  end
  exit 1
end