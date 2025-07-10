#!/usr/bin/env ruby

# Test what happens when we send an invalid message
require 'json'
require 'timeout'

def test_error_response
  puts "Testing MCP server error handling..."
  
  # Send an invalid message (missing required fields)
  invalid_msg = {
    "jsonrpc" => "2.0",
    "method" => "tools/call",
    "params" => {
      "name" => "NonExistentTool",
      "arguments" => {}
    },
    "id" => 999
  }.to_json
  
  IO.popen('./start_mcp.sh', 'r+') do |io|
    # First initialize properly
    init_msg = {
      "jsonrpc" => "2.0",
      "method" => "initialize",
      "params" => {
        "protocolVersion" => "2024-11-05",
        "capabilities" => {},
        "clientInfo" => {
          "name" => "test",
          "version" => "1.0.0"
        }
      },
      "id" => 1
    }.to_json
    
    io.puts init_msg
    io.flush
    
    # Read initialization response
    begin
      Timeout.timeout(2) do
        response = io.gets
        puts "Init response: #{response}"
      end
    rescue Timeout::Error
      puts "Timeout on init"
    end
    
    # Now send the invalid message
    io.puts invalid_msg
    io.flush
    
    # Read error response
    begin
      Timeout.timeout(2) do
        response = io.gets
        if response
          puts "Error response: #{response}"
          parsed = JSON.parse(response)
          puts "Parsed response:"
          puts "  id: #{parsed['id'].inspect} (class: #{parsed['id'].class})"
          puts "  error: #{parsed['error'].inspect}"
        end
      end
    rescue Timeout::Error
      puts "Timeout waiting for error response"
    rescue => e
      puts "Exception: #{e.message}"
    end
  end
end

test_error_response