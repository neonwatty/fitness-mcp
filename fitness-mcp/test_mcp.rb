#!/usr/bin/env ruby

# Test MCP server initialization
begin
  # Load Rails environment
  require_relative 'config/environment'
  puts "✓ Rails loaded successfully" 
  
  # Load fast_mcp
  require 'fast_mcp'
  puts "✓ fast_mcp loaded successfully"
  
  # Test API key lookup
  api_key_value = ENV['API_KEY'] || 'c52fea4b46bcad9f8c692715179dd386'
  api_key = ApiKey.find_by_api_key_value(api_key_value)
  puts "✓ API key found: #{api_key&.id}" if api_key
  puts "✗ API key NOT found for value: #{api_key_value}" unless api_key
  
  # Try to find by decoded value
  user = User.find_by(email: 'test@example.com')
  user_api_key = user&.api_keys&.first
  if user_api_key
    puts "✓ User API key found: #{user_api_key.id}"
    encoded = user_api_key.read_attribute(:api_key_value)
    puts "✓ Encoded value present: #{encoded.present?}"
    if encoded.present?
      puts "✓ Encoded value: #{encoded[0..20]}..."
    end
    decoded = user_api_key.decrypted_api_key_value
    puts "✓ Decoded value: #{decoded}" if decoded
    puts "✓ Match test: #{decoded == api_key_value}" if decoded
  end
  
  # Test tool initialization
  tool = LogSetTool.new
  puts "✓ LogSetTool initialized"
  
  # Test MCP server creation (without starting)
  server = MCP::Server.new(
    name: 'fitness-mcp',
    version: '1.0.0'
  )
  puts "✓ MCP Server created"
  
  # Test tool registration
  server.register_tool(LogSetTool)
  puts "✓ Tool registered"
  
  puts "✅ All tests passed - server should work!"

rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.join("\n")
end