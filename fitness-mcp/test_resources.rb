#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Test MCP resource access
def test_mcp_resources
  uri = URI('http://localhost:9999')
  http = Net::HTTP.new(uri.host, uri.port)
  
  # Initialize session
  init_request = {
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
      protocolVersion: "2024-11-05",
      capabilities: {}
    }
  }
  
  response = http.post('/', init_request.to_json, 'Content-Type' => 'application/json')
  puts "Initialize response: #{response.body}"
  
  # List resources
  list_request = {
    jsonrpc: "2.0", 
    id: 2,
    method: "resources/list"
  }
  
  response = http.post('/', list_request.to_json, 'Content-Type' => 'application/json')
  resources = JSON.parse(response.body)
  puts "\nAvailable resources:"
  resources['result']['resources'].each do |resource|
    puts "- #{resource['name']} (#{resource['uri']})"
  end
  
  # Read exercise list resource
  read_request = {
    jsonrpc: "2.0",
    id: 3,
    method: "resources/read",
    params: {
      uri: "fitness://exercises"
    }
  }
  
  response = http.post('/', read_request.to_json, 'Content-Type' => 'application/json')
  result = JSON.parse(response.body)
  
  if result['error']
    puts "\nError reading exercise list: #{result['error']['message']}"
  else
    puts "\nExercise list content:"
    puts JSON.pretty_generate(JSON.parse(result['result']['contents'][0]['text']))
  end
  
  # Read user stats (requires user_id)
  read_request = {
    jsonrpc: "2.0",
    id: 4,
    method: "resources/read",
    params: {
      uri: "fitness://stats/1"  # User ID 1
    }
  }
  
  response = http.post('/', read_request.to_json, 'Content-Type' => 'application/json')
  result = JSON.parse(response.body)
  
  if result['error']
    puts "\nError reading user stats: #{result['error']['message']}"
  else
    puts "\nUser stats content:"
    puts JSON.pretty_generate(JSON.parse(result['result']['contents'][0]['text']))
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end

# Start the test
test_mcp_resources