#!/usr/bin/env ruby

# Full MCP server test with initialization
require 'json'
require 'timeout'

# Test the server with the same initialization Claude sends
def test_mcp_server
  puts "Testing MCP server initialization..."
  
  # Create the initialization message that Claude sends
  init_msg = {
    "jsonrpc" => "2.0",
    "method" => "initialize",
    "params" => {
      "protocolVersion" => "2024-11-05",
      "capabilities" => {},
      "clientInfo" => {
        "name" => "claude-ai",
        "version" => "0.1.0"
      }
    },
    "id" => 0
  }.to_json
  
  # Start the server process
  IO.popen('./start_mcp.sh', 'r+') do |io|
    puts "Server started, sending initialization..."
    
    # Send the initialization message
    io.puts init_msg
    io.flush
    
    # Wait for response with timeout
    begin
      Timeout.timeout(5) do
        response = io.gets
        if response
          puts "Got response: #{response}"
          parsed = JSON.parse(response)
          puts "Response parsed successfully!"
          puts JSON.pretty_generate(parsed)
        else
          puts "No response received"
        end
      end
    rescue Timeout::Error
      puts "Timeout waiting for response"
    rescue JSON::ParserError => e
      puts "JSON parse error: #{e.message}"
      puts "Raw response: #{response}"
    rescue => e
      puts "Error: #{e.class} - #{e.message}"
    end
    
    # Try to get any error output
    begin
      Timeout.timeout(1) do
        while line = io.gets
          puts "Additional output: #{line}"
        end
      end
    rescue Timeout::Error
      # Expected
    end
  end
  
  puts "Test complete"
rescue => e
  puts "Test failed: #{e.message}"
  puts e.backtrace.join("\n")
end

# Run the test
ENV['API_KEY'] = 'c52fea4b46bcad9f8c692715179dd386'
test_mcp_server