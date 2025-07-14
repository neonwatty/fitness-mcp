#!/usr/bin/env ruby

# Simple MCP server test
puts "🧪 Testing MCP Server"

# Test 1: Check if server starts
puts "\n1. Testing server startup..."
result = `timeout 5 ./start_mcp_debug.sh 2>&1`
if $?.success?
  puts "✅ Server starts without errors"
else
  puts "❌ Server startup failed"
  puts result
  exit 1
end

# Test 2: Check JSON-RPC response
puts "\n2. Testing JSON-RPC communication..."
response = `echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' | timeout 5 ./start_mcp.sh`

if response.strip.start_with?('{"jsonrpc"')
  puts "✅ Server responds with valid JSON-RPC"
  
  # Parse and check response
  begin
    json = JSON.parse(response)
    if json['result'] && json['result']['serverInfo']
      puts "✅ Initialize response is valid"
      puts "   Server: #{json['result']['serverInfo']['name']}"
      puts "   Version: #{json['result']['serverInfo']['version']}"
    else
      puts "❌ Invalid initialize response"
    end
  rescue JSON::ParserError
    puts "❌ Response is not valid JSON"
  end
else
  puts "❌ Server does not respond with JSON-RPC"
  puts "Response: #{response}"
end

# Test 3: Check tools list
puts "\n3. Testing tools list..."
tools_response = `echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | timeout 5 ./start_mcp.sh`

if tools_response.strip.start_with?('{"jsonrpc"')
  begin
    json = JSON.parse(tools_response)
    if json['result'] && json['result']['tools']
      tool_count = json['result']['tools'].length
      puts "✅ Tools list works - found #{tool_count} tools"
      json['result']['tools'].each_with_index do |tool, i|
        puts "   #{i+1}. #{tool['name']}"
      end
    else
      puts "❌ Invalid tools response"
    end
  rescue JSON::ParserError
    puts "❌ Tools response is not valid JSON"
  end
else
  puts "❌ Tools list failed"
  puts "Response: #{tools_response}"
end

puts "\n🎉 MCP Server test completed!"