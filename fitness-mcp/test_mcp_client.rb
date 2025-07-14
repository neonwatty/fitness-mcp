#!/usr/bin/env ruby

# Interactive MCP client for testing the server
require 'json'
require 'open3'
require 'timeout'

class MCPTestClient
  def initialize(command)
    @command = command
    @id = 0
  end

  def start
    puts "🧪 Starting MCP Test Client"
    puts "=" * 40
    
    @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(@command)
    
    # Give server time to start
    sleep 2
    
    puts "🔗 Connected to MCP server"
    puts "📡 Sending initialize request..."
    
    # Initialize connection
    response = call_method("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {
        roots: {
          listChanged: true
        },
        sampling: {}
      },
      clientInfo: {
        name: "test-client",
        version: "1.0.0"
      }
    })
    
    if response['result']
      puts "✅ Server initialized successfully!"
      puts "   Server: #{response['result']['serverInfo']['name']} v#{response['result']['serverInfo']['version']}"
      puts "   Protocol: #{response['result']['protocolVersion']}"
      
      # List tools
      puts "\n🔧 Getting available tools..."
      tools_response = call_method("tools/list", {})
      
      if tools_response['result']
        tools = tools_response['result']['tools']
        puts "✅ Found #{tools.length} tools:"
        tools.each_with_index do |tool, i|
          puts "   #{i+1}. #{tool['name']} - #{tool['description']}"
        end
        
        # Test a tool
        puts "\n🏋️  Testing LogSetTool..."
        log_response = call_method("tools/call", {
          name: "LogSetTool",
          arguments: {
            exercise: "test squat",
            weight: 135,
            reps: 5
          }
        })
        
        if log_response['result']
          puts "✅ Tool test successful!"
          puts "   Result: #{log_response['result']}"
        else
          puts "❌ Tool test failed: #{log_response['error']}"
        end
        
        # Test another tool
        puts "\n📊 Testing GetRecentSetsTool..."
        recent_response = call_method("tools/call", {
          name: "GetRecentSetsTool",
          arguments: {
            limit: 5
          }
        })
        
        if recent_response['result']
          puts "✅ Recent sets tool successful!"
          puts "   Result: #{recent_response['result']}"
        else
          puts "❌ Recent sets tool failed: #{recent_response['error']}"
        end
        
      else
        puts "❌ Failed to get tools: #{tools_response['error']}"
      end
    else
      puts "❌ Initialization failed: #{response['error']}"
    end
    
    puts "\n🎉 Test completed!"
    
  rescue => e
    puts "❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
  ensure
    cleanup
  end

  private

  def call_method(method, params)
    request = {
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: @id += 1
    }
    
    puts "📤 Sending: #{method}"
    
    # Send request
    @stdin.puts(request.to_json)
    @stdin.flush
    
    # Read response with timeout
    begin
      Timeout.timeout(10) do
        response_line = @stdout.gets
        if response_line
          response = JSON.parse(response_line)
          puts "📥 Received response for ID #{response['id']}"
          return response
        else
          puts "❌ No response received"
          return {"error" => {"message" => "No response"}}
        end
      end
    rescue Timeout::Error
      puts "⏰ Request timed out"
      return {"error" => {"message" => "Timeout"}}
    rescue JSON::ParserError => e
      puts "❌ Invalid JSON response: #{e.message}"
      return {"error" => {"message" => "Invalid JSON"}}
    end
  end

  def cleanup
    @stdin&.close
    @stdout&.close
    @stderr&.close
    Process.kill("TERM", @wait_thr.pid) if @wait_thr
  rescue
    # Ignore cleanup errors
  end
end

# Run the test
if __FILE__ == $0
  if ARGV[0] == "help" || ARGV.empty?
    puts "Usage: #{$0} [command]"
    puts "Examples:"
    puts "  #{$0} './start_mcp_debug.sh'  # Test the debug server"
    puts "  #{$0} './start_mcp.sh'       # Test the production server"
    exit
  end
  
  command = ARGV[0]
  client = MCPTestClient.new(command)
  client.start
end