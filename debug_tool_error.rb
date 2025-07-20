#!/usr/bin/env ruby

# Debug script to identify the tool error
require_relative 'config/environment'
require_relative 'config/mcp_server'

puts "🔍 Debugging Tool Error"
puts "=" * 40

begin
  puts "1. Loading server..."
  server = FitnessMcp::Server.build(mode: :debug)
  puts "✅ Server loaded successfully"
  
  puts "\n2. Checking tool classes..."
  [LogSetTool, GetLastSetTool, GetLastSetsTool, GetRecentSetsTool, DeleteLastSetTool, AssignWorkoutTool].each do |tool_class|
    puts "  Testing #{tool_class}..."
    tool = tool_class.new
    puts "  ✅ #{tool_class} instantiated"
    
    # Check available methods
    methods = tool.methods.grep(/headers|call|perform/)
    puts "    Available methods: #{methods}"
    
    # Check if it has the problematic method
    if tool.respond_to?(:headers)
      puts "    ⚠️  Tool responds to :headers"
    else
      puts "    ✅ Tool does not respond to :headers"
    end
  end
  
  puts "\n3. Testing server registration..."
  tools = server.tools
  puts "  Registered tools: #{tools.keys}"
  
  puts "\n4. Testing FastMcp::Tool base class..."
  base_methods = FastMcp::Tool.instance_methods(false)
  puts "  FastMcp::Tool methods: #{base_methods}"
  
  if base_methods.include?(:headers)
    puts "  ⚠️  FastMcp::Tool has :headers method"
  else
    puts "  ✅ FastMcp::Tool does not have :headers method"
  end

rescue => e
  puts "❌ Error occurred: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(10)
end

puts "\n" + "=" * 40
puts "Debug complete"