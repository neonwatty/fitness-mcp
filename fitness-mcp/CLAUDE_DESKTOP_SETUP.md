# Claude Desktop Setup for Fitness MCP

## Prerequisites

1. Ensure the fitness-mcp Rails server is set up with:
   - Database migrated (`rails db:migrate`)
   - A user and API key created in the database

## Setup Steps

1. **Locate your Claude Desktop configuration file:**
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`
   - Linux: `~/.config/Claude/claude_desktop_config.json`

2. **Add the fitness-mcp configuration:**
   
   Edit the configuration file and add the following to the `mcpServers` section:

   ```json
   {
     "mcpServers": {
       "fitness-mcp": {
         "command": "/path/to/fitness-mcp/start_mcp.sh",
         "env": {
           "API_KEY": "your-api-key-here"
         }
       }
     }
   }
   ```

   Replace:
   - `/path/to/fitness-mcp` with the actual path to your fitness-mcp directory
   - `your-api-key-here` with your actual API key

3. **Create an API key (if you haven't already):**

   ```bash
   cd /path/to/fitness-mcp
   rails console
   ```

   Then in the Rails console:
   ```ruby
   # Create a user
   user = User.create!(email: 'your-email@example.com', password: 'your-password')
   
   # Generate an API key
   api_key_value = SecureRandom.hex(16)
   api_key = ApiKey.create!(
     user: user,
     name: 'Claude Desktop',
     api_key_hash: ApiKey.hash_key(api_key_value),
     api_key_value: api_key_value
   )
   
   puts "Your API key: #{api_key_value}"
   ```

4. **Restart Claude Desktop** to load the new configuration

## Testing

Once configured, you can test the fitness tools in Claude Desktop:

- "Log my workout: 3 sets of 10 reps bench press at 135 lbs"
- "What was my last squat set?"
- "Show me my recent workouts"
- "Delete my last deadlift set"
- "Create a workout plan for tomorrow"

## Troubleshooting

1. **Check logs:**
   - MCP startup log: `/tmp/mcp_startup.log`
   - MCP debug log: `/tmp/mcp_debug.log` (if MCP_DEBUG=1 is set)
   - MCP requests log: `/tmp/mcp_requests.log` (if MCP_DEBUG=1 is set)

2. **Verify the server starts manually:**
   ```bash
   API_KEY=your-api-key ./start_mcp.sh
   ```
   
   You should see no output (the server is waiting for JSON-RPC input).
   Press Ctrl+C to exit.

3. **Common issues:**
   - Ensure Ruby path in `start_mcp.sh` matches your Ruby installation
   - Check that the database file exists and has proper permissions
   - Verify the API key exists in the database and is not revoked