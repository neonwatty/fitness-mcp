#!/bin/bash
# Debug version of MCP server startup

# Set the API key for testing
export API_KEY="c52fea4b46bcad9f8c692715179dd386"

# Ensure we use the correct Ruby version
export PATH="/Users/jeremywatt/.local/share/mise/installs/ruby/3.4.2/bin:$PATH"

# Start the server in STDIO mode with error logging
cd "$(dirname "$0")"
/Users/jeremywatt/.local/share/mise/installs/ruby/3.4.2/bin/ruby bin/mcp_server.rb stdio 2>/tmp/mcp_debug.log