#!/usr/bin/env ruby

# Test script for MCP refactoring
require_relative 'config/environment'
require_relative 'config/mcp_server'

puts "🧪 Testing MCP Refactoring Implementation"
puts "=" * 50

# Test 1: Server instantiation
puts "\n1. Testing server instantiation..."
begin
  server = FitnessMcp::Server.build(mode: :debug)
  puts "✅ Server created successfully"
  puts "   - Name: #{server.name}"
  puts "   - Version: #{server.version}"
  puts "   - Tools: #{server.tools.count}"
  puts "   - Resources: #{server.resources.count}"
rescue => e
  puts "❌ Server creation failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 2: Tool instantiation
puts "\n2. Testing tool instantiation..."
begin
  tool = LogSetTool.new
  puts "✅ LogSetTool instantiated"
rescue => e
  puts "❌ LogSetTool instantiation failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 3: Tool execution (with authentication)
puts "\n3. Testing tool execution..."
begin
  # Get a test user
  user = User.first
  if user
    puts "   Using test user: #{user.email}"
    
    # Test tool call with authentication
    api_key = ENV['API_KEY'] || 'c52fea4b46bcad9f8c692715179dd386'
    tool = LogSetTool.new(api_key: api_key)
    result = tool.call(
      exercise: 'test squat',
      weight: 225.0,
      reps: 5
    )
    puts "✅ Tool execution successful"
    puts "   Result: #{result}"
  else
    puts "⚠️  No test user found - skipping tool execution test"
  end
rescue => e
  puts "❌ Tool execution failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 4: Resource instantiation
puts "\n4. Testing resource instantiation..."
begin
  resource = ExerciseListResource.new
  puts "✅ ExerciseListResource instantiated"
rescue => e
  puts "❌ ExerciseListResource instantiation failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 5: Resource content generation
puts "\n5. Testing resource content generation..."
begin
  resource = ExerciseListResource.new
  content = resource.content
  puts "✅ ExerciseListResource content generated"
  puts "   Content length: #{content.length} characters"
  puts "   First 100 chars: #{content[0..100]}..."
rescue => e
  puts "❌ Resource content generation failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 6: Templated resource
puts "\n6. Testing templated resource..."
begin
  user = User.first
  if user
    # This is tricky - we need to simulate how fast-mcp would call this
    resource = WorkoutHistoryResource.new
    
    # Create a mock params object
    class MockParams
      def initialize(params)
        @params = params
      end
      
      def [](key)
        @params[key]
      end
    end
    
    # Try to manually set params
    resource.instance_variable_set(:@params, MockParams.new(user_id: user.id.to_s))
    
    # Also need to set the ENV variable for authentication
    ENV['API_KEY'] = 'c52fea4b46bcad9f8c692715179dd386'
    
    content = resource.content
    puts "✅ WorkoutHistoryResource content generated"
    puts "   Content length: #{content.length} characters"
  else
    puts "⚠️  No test user found - skipping templated resource test"
  end
rescue => e
  puts "❌ Templated resource test failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 7: Database queries in resources
puts "\n7. Testing database queries..."
begin
  # Test if we have any set entries
  set_count = SetEntry.count
  puts "✅ Database accessible"
  puts "   Set entries count: #{set_count}"
  
  if set_count > 0
    # Test the complex query from UserStatsResource
    user = User.joins(:set_entries).first
    if user
      recent_sets = user.set_entries.where('timestamp >= ?', 30.days.ago)
      puts "✅ Complex database query successful"
      puts "   Recent sets: #{recent_sets.count}"
    end
  end
rescue => e
  puts "❌ Database query test failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 8: Authentication
puts "\n8. Testing authentication..."
begin
  api_key = ENV['API_KEY'] || 'c52fea4b46bcad9f8c692715179dd386'
  if api_key
    key_hash = ApiKey.hash_key(api_key)
    api_key_record = ApiKey.active.find_by(api_key_hash: key_hash)
    
    if api_key_record
      puts "✅ Authentication working"
      puts "   API key found for user: #{api_key_record.user.email}"
    else
      puts "❌ Authentication failed - API key not found in database"
      puts "   Looking for hash: #{key_hash}"
      puts "   Available API keys: #{ApiKey.count}"
    end
  else
    puts "⚠️  No API key set - skipping authentication test"
  end
rescue => e
  puts "❌ Authentication test failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 9: Server resource registration
puts "\n9. Testing server resource registration..."
begin
  server = FitnessMcp::Server.build(mode: :debug)
  
  # Check if resources are properly registered
  resource_uris = server.resources.map(&:uri)
  puts "✅ Resources registered:"
  resource_uris.each { |uri| puts "   - #{uri}" }
  
  # Check if tools are properly registered
  puts "✅ Tools registered:"
  server.tools.each do |tool_name, tool_class|
    puts "   - #{tool_name} (#{tool_class})"
  end
rescue => e
  puts "❌ Server registration test failed: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 50
puts "🏁 Test Summary Complete"
puts "Review the results above to identify any issues."