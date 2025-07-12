#!/bin/bash
# Start the Fitness MCP Server

# Set the API key for testing (only if not already set by Claude Desktop)
if [ -z "$API_KEY" ]; then
    export API_KEY="c52fea4b46bcad9f8c692715179dd386"
fi

# Ensure we use the correct Ruby version (mise/rbenv)
export PATH="/Users/jeremywatt/.local/share/mise/installs/ruby/3.4.2/bin:$PATH"

# Start the server in STDIO mode
cd "$(dirname "$0")"

# Run the clean server and filter out log lines (keep only JSON-RPC responses)
/Users/jeremywatt/.local/share/mise/installs/ruby/3.4.2/bin/ruby mcp_server_clean.rb stdio 2>/dev/null | grep '^{'