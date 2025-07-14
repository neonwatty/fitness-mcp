# MCP Refactoring Strategy Using fast-mcp Ruby Gem

## Current State Analysis

Your fitness-mcp repository currently uses fast-mcp v0.1.0 with:
- Three MCP server implementations (fast, clean, debug)
- Six fitness tools (log set, get last set, get recent sets, etc.)
- Authentication via API keys
- Audit logging for tool usage
- STDIO and HTTP transport support

## Refactoring Opportunities

### 1. Upgrade to Latest fast-mcp Features

Update the Gemfile to use the latest version from GitHub:
```ruby
gem 'fast-mcp', github: 'yjacquin/fast-mcp'
```

### 2. Implement Resource API

The fast-mcp gem supports resources for sharing data. Add fitness data resources:

```ruby
class WorkoutHistoryResource < FastMcp::Resource
  uri "fitness://history/{user_id}"
  mime_type "application/json"
  
  def read(uri_params:)
    user = User.find(uri_params[:user_id])
    {
      contents: user.set_entries.recent.to_json,
      mime_type: "application/json"
    }
  end
end

class UserStatsResource < FastMcp::Resource
  uri "fitness://stats/{user_id}"
  
  def read(uri_params:)
    user = User.find(uri_params[:user_id])
    {
      total_sets: user.set_entries.count,
      total_weight: user.set_entries.sum(:weight),
      recent_workouts: user.workout_assignments.recent
    }
  end
end
```

### 3. Unified Server Configuration

Create a single, configurable MCP server:

```ruby
# config/mcp_server.rb
module FitnessMcp
  class Server
    def self.build(mode: :production)
      server = FastMcp::Server.new(
        name: 'fitness-mcp',
        version: '2.0.0',
        description: 'Fitness tracking MCP server'
      )
      
      # Configure based on mode
      case mode
      when :debug
        server.logger.level = Logger::DEBUG
      when :production
        server.logger.level = Logger::ERROR
      when :fast
        server.logger = Logger.new('/dev/null')
      end
      
      # Register tools with dynamic filtering
      register_tools(server)
      register_resources(server)
      
      server
    end
    
    private
    
    def self.register_tools(server)
      tool_classes = [
        LogSetTool, GetLastSetTool, GetLastSetsTool,
        GetRecentSetsTool, DeleteLastSetTool, AssignWorkoutTool
      ]
      
      tool_classes.each do |tool_class|
        server.register_tool(tool_class) do |context|
          # Dynamic filtering based on user permissions
          user = context[:user]
          next false unless user
          
          # Example: Only admins can delete sets
          if tool_class == DeleteLastSetTool
            user.admin?
          else
            true
          end
        end
      end
    end
    
    def self.register_resources(server)
      server.register_resource(WorkoutHistoryResource)
      server.register_resource(UserStatsResource)
    end
  end
end
```

### 4. Improved Tool Base Class

Refactor ApplicationTool to leverage fast-mcp features:

```ruby
class ApplicationTool < FastMcp::Tool
  # Use fast-mcp's built-in authentication
  before_call :authenticate_user!
  after_call :log_audit
  
  def authenticate_user!
    api_key = context[:api_key] || ENV['API_KEY']
    
    unless api_key && current_user(api_key)
      raise FastMcp::AuthenticationError, "Invalid API key"
    end
  end
  
  def current_user(api_key = nil)
    api_key ||= context[:api_key]
    return nil unless api_key
    
    key_hash = ApiKey.hash_key(api_key)
    api_key_record = ApiKey.active.find_by(api_key_hash: key_hash)
    api_key_record&.user
  end
  
  def log_audit(result:, error: nil)
    McpAuditLog.log_tool_usage(
      user: current_user,
      tool_name: self.class.name,
      arguments: context[:arguments],
      result_success: error.nil?,
      execution_time: context[:execution_time]
    )
  end
end
```

### 5. Rails Integration

Use fast-mcp's Rails integration:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount FitnessMcp::Server.build.rack_app, at: '/mcp'
  
  # SSE endpoint for real-time updates
  get '/mcp/events', to: 'mcp#events'
end

# app/controllers/mcp_controller.rb
class McpController < ApplicationController
  include FastMcp::Rails::Controller
  
  def events
    response.headers['Content-Type'] = 'text/event-stream'
    
    sse = FastMcp::SSE.new(response.stream)
    server = FitnessMcp::Server.build
    
    server.handle_sse(sse, context: { user: current_user })
  ensure
    sse.close
  end
end
```

### 6. Enhanced Transport Support

Add SSE transport for real-time updates:

```ruby
# mcp_server.rb
#!/usr/bin/env ruby

require_relative 'config/environment'
require_relative 'config/mcp_server'

server = FitnessMcp::Server.build(mode: ENV['MCP_MODE']&.to_sym || :production)

case ARGV[0]
when 'stdio'
  server.start_stdio
when 'http'
  port = ARGV[1] || 8080
  server.start_http(port: port.to_i)
when 'sse'
  # Start with SSE support
  app = Rack::Builder.new do
    use FastMcp::Middleware::DNSRebindingProtection
    use FastMcp::Middleware::CORS
    run server.rack_app
  end
  
  Rack::Handler::Puma.run(app, Port: 8080)
else
  puts "Usage: #{$0} [stdio|http|sse] [port]"
  exit 1
end
```

### 7. Security Enhancements

Add DNS rebinding protection and enhanced authentication:

```ruby
# config/initializers/mcp_security.rb
FastMcp.configure do |config|
  config.dns_rebinding_protection = true
  config.allowed_hosts = ['localhost', 'fitness-mcp.local']
  
  # Custom authentication handler
  config.authenticate = ->(context) do
    api_key = context[:headers]['X-API-Key'] || context[:api_key]
    ApiKey.authenticate(api_key)
  end
end
```

### 8. Testing Improvements

Create comprehensive tests for MCP functionality:

```ruby
# test/mcp/server_test.rb
require 'test_helper'
require 'fast_mcp/test_helpers'

class McpServerTest < ActiveSupport::TestCase
  include FastMcp::TestHelpers
  
  def setup
    @server = FitnessMcp::Server.build(mode: :test)
    @client = FastMcp::TestClient.new(@server)
  end
  
  test "log set tool creates entry" do
    result = @client.call_tool('LogSetTool', 
      exercise: 'squat',
      weight: 225,
      reps: 5
    )
    
    assert result[:success]
    assert_equal 1, SetEntry.count
  end
  
  test "resources require authentication" do
    assert_raises(FastMcp::AuthenticationError) do
      @client.read_resource('fitness://history/1')
    end
  end
end
```

## Implementation Steps

1. **Phase 1: Core Upgrade**
   - Update Gemfile to use latest fast-mcp
   - Refactor ApplicationTool to use new features
   - Create unified server configuration

2. **Phase 2: New Features**
   - Implement Resource API for fitness data
   - Add SSE transport support
   - Implement dynamic tool filtering

3. **Phase 3: Integration**
   - Update Rails routes and controllers
   - Add security middleware
   - Create comprehensive tests

4. **Phase 4: Optimization**
   - Profile and optimize startup time
   - Implement caching for resources
   - Add connection pooling for database

## Benefits

1. **Cleaner Architecture**: Single server configuration instead of three separate files
2. **Better Features**: Resources, SSE, dynamic filtering
3. **Enhanced Security**: Built-in DNS rebinding protection, better auth
4. **Improved Testing**: Using fast-mcp's test helpers
5. **Real-time Updates**: SSE support for live fitness tracking
6. **Better Rails Integration**: Native Rails controller support

## Migration Notes

- The new structure is backward compatible with existing tools
- API keys continue to work the same way
- STDIO and HTTP transports remain supported
- New features are additive, not breaking