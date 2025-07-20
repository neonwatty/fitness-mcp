#!/bin/bash

# Script to clean up temporary test files from repository root
# Run this script from the repository root: ./cleanup_temp_files.sh

echo "Cleaning up temporary test files..."

# Remove temporary test scripts
rm -f cursor_test.rb
rm -f debug_tool_error.rb
rm -f test_error_response.rb
rm -f test_final.rb
rm -f test_mcp.rb
rm -f test_mcp_full.rb
rm -f test_resources.rb
rm -f test_simple.rb
rm -f test_startup_error.rb

# Remove redundant MCP server variants
rm -f mcp_server_clean.rb
rm -f mcp_server_fast.rb

echo "Cleanup complete!"
echo ""
echo "Files that should remain:"
echo "- mcp_server.rb (primary production server)"
echo "- mcp_server_debug.rb (debug version)"
echo "- add_sample_data.rb (test data population)"
echo "- chat_with_mcp.rb (interactive testing)"
echo "- test_mcp_client.rb (MCP protocol testing)"
echo "- test_mcp_refactor.rb (comprehensive test suite)"