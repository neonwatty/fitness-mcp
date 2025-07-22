#!/bin/bash
# Start the Fitness MCP Server with debugging

echo "🏋️  Starting Fitness MCP Server (Debug Mode)"
echo "============================================"

# Set the API key for testing (only if not already set by Claude Desktop)
if [ -z "$API_KEY" ]; then
    export API_KEY="c52fea4b46bcad9f8c692715179dd386"
    echo "📋 Using default API key: ${API_KEY:0:8}..."
fi

# Ensure we use the correct Ruby version (mise/rbenv)
export PATH="/Users/jeremywatt/.local/share/mise/installs/ruby/3.4.2/bin:$PATH"

echo "🔧 Ruby path: $(which ruby)"
echo "📁 Working directory: $(pwd)"
echo "⏰ Starting at: $(date)"

# Start the server in STDIO mode
cd "$(dirname "$0")"

echo "🚀 Launching MCP server..."
echo "📝 Server output will appear below:"
echo "-----------------------------------"

# Run the debug server with visible logging
/Users/jeremywatt/.local/share/mise/installs/ruby/3.4.2/bin/ruby mcp_server_debug.rb stdio