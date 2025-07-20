#!/usr/bin/env ruby

# For STDIO mode, prepare for clean JSON-RPC communication
if ARGV[0] == 'stdio'
  $stdout.sync = true
  $stderr.sync = true
end

# Load Rails environment
begin
  # Log startup information to a file
  if ARGV[0] == 'stdio'
    File.open('/tmp/mcp_startup.log', 'a') do |f|
      f.puts "[#{Time.now}] Starting MCP server..."
      f.puts "[#{Time.now}] Working directory: #{Dir.pwd}"
      f.puts "[#{Time.now}] Ruby version: #{RUBY_VERSION}"
      f.puts "[#{Time.now}] Rails environment: #{ENV['RAILS_ENV'] || 'development'}"
    end
  end
  
  begin
    require_relative '../config/environment'
  rescue => rails_error
    if ARGV[0] == 'stdio'
      File.open('/tmp/mcp_startup.log', 'a') do |f|
        f.puts "[#{Time.now}] Rails loading error: #{rails_error.message}"
        f.puts rails_error.backtrace.first(10).join("\n")
      end
      # Exit cleanly for STDIO mode
      exit 1
    else
      raise rails_error
    end
  end
  
  # Load fast_mcp after Rails is ready
  
  require 'fast_mcp'
  
  if ARGV[0] == 'stdio'
    File.open('/tmp/mcp_startup.log', 'a') do |f|
      f.puts "[#{Time.now}] Rails loaded successfully"
      f.puts "[#{Time.now}] Database config: #{Rails.application.config.database_configuration[Rails.env]}"
      
      # Test database connectivity
      begin
        f.puts "[#{Time.now}] Testing database connection..."
        ActiveRecord::Base.connection.execute("SELECT 1")
        f.puts "[#{Time.now}] Database connection successful"
        
        # Check if tables exist
        f.puts "[#{Time.now}] Tables in database: #{ActiveRecord::Base.connection.tables.join(', ')}"
        
        # Check if we can query users
        user_count = User.count rescue "Error: #{$!.message}"
        f.puts "[#{Time.now}] User count: #{user_count}"
      rescue => e
        f.puts "[#{Time.now}] Database error: #{e.message}"
        f.puts e.backtrace.first(5).join("\n")
      end
    end
  end
rescue => e
  if ARGV[0] == 'stdio'
    File.open('/tmp/mcp_startup.log', 'a') do |f|
      f.puts "[#{Time.now}] Error loading Rails: #{e.message}"
      f.puts e.backtrace.join("\n")
    end
  end
  raise
end

# For STDIO mode, configure minimal logging to avoid JSON-RPC interference  
if ARGV[0] == 'stdio'
  # Redirect STDERR to /dev/null to suppress Rails logging
  $stderr.reopen('/dev/null', 'w')
  
  # Configure Rails to log to file instead of STDOUT/STDERR
  Rails.logger = Logger.new('/tmp/mcp_rails.log')
  Rails.logger.level = Logger::ERROR
  
  # Suppress all Active Record logging to STDOUT
  ActiveRecord::Base.logger = Rails.logger if defined?(ActiveRecord)
  
  # Suppress other Rails loggers
  ActionController::Base.logger = Rails.logger if defined?(ActionController)
  ActionView::Base.logger = Rails.logger if defined?(ActionView)
  ActionMailer::Base.logger = Rails.logger if defined?(ActionMailer)
  ActiveJob::Base.logger = Rails.logger if defined?(ActiveJob)
  ActionCable.server.config.logger = Rails.logger if defined?(ActionCable)
  
  # Configure application logger
  Rails.application.config.logger = Rails.logger
  Rails.application.config.log_level = :error
end

# Create MCP server with proper logger and error handling
class FitnessMCPServer < MCP::Server
  def handle_request(request)
    # Log the request for debugging (to file, not STDOUT)
    if ENV['MCP_DEBUG']
      File.open('/tmp/mcp_requests.log', 'a') do |f|
        f.puts "[#{Time.now}] Request: #{request.inspect}"
      end
    end
    
    result = super
    
    # Log the response for debugging (to file, not STDOUT)
    if ENV['MCP_DEBUG']
      File.open('/tmp/mcp_requests.log', 'a') do |f|
        f.puts "[#{Time.now}] Response: #{result.inspect}"
      end
    end
    
    result
  rescue => e
    # Log the error for debugging
    if ENV['MCP_DEBUG']
      File.open('/tmp/mcp_requests.log', 'a') do |f|
        f.puts "[#{Time.now}] Error: #{e.message}"
        f.puts e.backtrace.first(5).join("\n")
      end
    end
    
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

# Create appropriate logger for the mode
logger = if ARGV[0] == 'stdio'
  # For STDIO mode, create a logger that writes to file to avoid JSON-RPC interference
  file_logger = Logger.new('/tmp/mcp_server.log')
  file_logger.level = Logger::ERROR  # Only log errors
  file_logger
else
  # For other modes, use standard STDOUT logger
  Logger.new(STDOUT)
end

server = FitnessMCPServer.new(
  name: 'fitness-mcp',
  version: '1.0.0',
  logger: logger
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
    File.open('/tmp/mcp_server_error.log', 'a') do |f|
      f.puts "[#{Time.now}] Starting MCP server in STDIO mode..."
      f.puts "[#{Time.now}] Server class: #{server.class}"
      f.puts "[#{Time.now}] Tools registered: #{server.tools.keys.join(', ')}"
    end
    
    # Ensure STDOUT is in sync mode for MCP
    $stdout.sync = true
    
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
      f.puts "[#{Time.now}] Error class: #{e.class}"
      f.puts e.backtrace.join("\n")
      f.puts "---"
    end
  else
    puts "Error: #{e.message}"
    puts e.backtrace.join("\n")
  end
  exit 1
end