#!/bin/bash
# Start the Fitness MCP Server

# Set the API key for testing
export API_KEY="c52fea4b46bcad9f8c692715179dd386"

# Start the server in STDIO mode
cd "$(dirname "$0")"
ruby bin/mcp_server.rb stdio