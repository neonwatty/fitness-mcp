#!/usr/bin/env ruby

# Test if there's an error during MCP server startup
require 'open3'
require 'json'
require 'timeout'

puts "Testing MCP server startup with stderr capture..."

# Start the server and capture both stdout and stderr
Open3.popen3('./start_mcp.sh') do |stdin, stdout, stderr, wait_thr|
  # Send initialization
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
    "id" => 0
  }.to_json
  
  stdin.puts init_msg
  stdin.flush
  
  # Read responses with timeout
  puts "=== STDOUT ==="
  begin
    Timeout.timeout(3) do
      while line = stdout.gets
        puts "STDOUT: #{line}"
      end
    end
  rescue Timeout::Error
    # Expected
  end
  
  puts "\n=== STDERR ==="
  begin
    Timeout.timeout(1) do
      while line = stderr.gets
        puts "STDERR: #{line}"
      end
    end
  rescue Timeout::Error
    # Expected
  end
  
  # Check if process is still running
  puts "\nProcess still running: #{wait_thr.alive?}"
end