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
  
  # MUST monkey-patch MCP::Logger BEFORE loading fast_mcp
  if ARGV[0] == 'stdio'
    require 'logger'
    module MCP
      class Logger < ::Logger
        def initialize(*args)
          # Always log to /dev/null for STDIO mode
          super('/dev/null')
          @client_initialized = false
          @transport = nil
        end
        
        attr_accessor :transport, :client_initialized
        
        def client_initialized?
          @client_initialized
        end
        
        def stdio_transport?
          transport == :stdio
        end
        
        def rack_transport?
          transport == :rack
        end
        
        # Override all logging methods to be no-ops
        def add(*args); end
        def log(*args); end
        def <<(*args); end
        def debug(*args); end
        def info(*args); end
        def warn(*args); end
        def error(*args); end
        def fatal(*args); end
        def unknown(*args); end
        def close; end
        def level; Logger::FATAL; end
        def level=(val); end
      end
    end
  end
  
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

# For STDIO mode, restore STDOUT and configure minimal logging
if ARGV[0] == 'stdio'
  # Restore STDOUT for JSON-RPC communication
  $stdout.reopen(original_stdout)
  
  # Keep STDERR redirected to /dev/null
  Rails.logger = Logger.new('/dev/null')
  Rails.logger.level = Logger::FATAL
  
  # Suppress all Active Record logging
  ActiveRecord::Base.logger = nil if defined?(ActiveRecord)
  
  # Suppress other Rails loggers
  ActionController::Base.logger = nil if defined?(ActionController)
  ActionView::Base.logger = nil if defined?(ActionView)
  ActionMailer::Base.logger = nil if defined?(ActionMailer)
  ActiveJob::Base.logger = nil if defined?(ActiveJob)
  ActionCable.server.config.logger = nil if defined?(ActionCable)
  
  # Suppress Rack logger
  Rails.application.config.logger = Logger.new('/dev/null')
  Rails.application.config.log_level = :fatal
  
  # Disable request logging middleware
  Rails.application.config.middleware.delete(Rails::Rack::Logger) if defined?(Rails::Rack::Logger)
  Rails.application.config.middleware.delete(ActionDispatch::DebugExceptions) if defined?(ActionDispatch::DebugExceptions)
  
  # Close the null file
  null_file.close
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

# Create a no-op logger for STDIO mode
logger = if ARGV[0] == 'stdio'
  MCP::Logger.new  # Will use our monkey-patched version
else
  Logger.new(STDOUT)  # Use standard logger for non-STDIO mode
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