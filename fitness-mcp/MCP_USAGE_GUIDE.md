# Fitness MCP Server Usage Guide

## 🏃‍♂️ Overview

The Fitness MCP Server provides workout tracking tools for LLMs like Claude Desktop. It includes comprehensive audit logging and multi-user support.

## 🔧 Setup Instructions

### 1. Start the MCP Server

```bash
# From the fitness-mcp directory
./start_mcp.sh
```

### 2. Configure Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "fitness-mcp": {
      "command": "/Users/jeremywatt/Desktop/fitness-mcp/fitness-mcp/start_mcp.sh",
      "args": [],
      "env": {
        "API_KEY": "c52fea4b46bcad9f8c692715179dd386"
      }
    }
  }
}
```

### 3. Restart Claude Desktop

After adding the configuration, restart Claude Desktop to load the MCP server.

## 🛠️ Available Tools

### 1. **LogSetTool** - Log workout sets
```
Description: Log a workout set with exercise, weight, and reps
Arguments:
  - exercise (string, required): Name of the exercise
  - weight (number, required): Weight in pounds
  - reps (integer, required): Number of repetitions
  - timestamp (string, optional): ISO timestamp (defaults to now)
```

### 2. **GetLastSetTool** - Get last set for exercise
```
Description: Get the most recent set for a specific exercise
Arguments:
  - exercise (string, required): Name of the exercise
```

### 3. **GetLastSetsTool** - Get N last sets for exercise
```
Description: Get the last N sets for a specific exercise
Arguments:
  - exercise (string, required): Name of the exercise
  - limit (integer, optional): Number of sets to retrieve (default: 5, max: 20)
```

### 4. **GetRecentSetsTool** - Get N recent sets (all exercises)
```
Description: Get the most recent N sets across all exercises
Arguments:
  - limit (integer, optional): Number of sets to retrieve (default: 10, max: 50)
```

### 5. **DeleteLastSetTool** - Delete most recent set
```
Description: Delete the most recent workout set
Arguments: None
```

### 6. **AssignWorkoutTool** - Assign workout plan
```
Description: Assign a workout plan to the user
Arguments:
  - assignment_name (string, required): Name of the workout assignment
  - scheduled_for (string, required): ISO timestamp for when workout is scheduled
  - config (object, required): Workout configuration object
```

## 💡 Example Usage with Claude

### Logging a workout set:
```
"I just did 3 sets of bench press at 185 lbs for 8 reps. Can you log this for me?"
```

### Getting workout history:
```
"Show me my last 5 bench press sets"
```

### Getting recent activity:
```
"What are my 10 most recent workout sets across all exercises?"
```

### Deleting a mistaken entry:
```
"I accidentally logged a set, can you delete my last entry?"
```

## 🔐 Authentication & Security

- **API Key**: Each MCP connection uses an API key for authentication
- **User Isolation**: Different API keys access different user data
- **Audit Logging**: All tool usage is logged with timestamps and arguments
- **Error Handling**: Invalid keys are rejected with clear error messages

## 📊 Audit Logging

Every tool call is automatically logged with:
- User ID and API key used
- Tool name and arguments
- Success/failure status
- Timestamp and IP address
- Full argument details for debugging

## 🚀 Testing the Connection

### Test with Claude Desktop:
1. Start Claude Desktop
2. Look for the MCP server in the tool picker
3. Try: "Log a workout set for squats, 225 lbs, 5 reps"
4. Try: "Show me my recent workout history"

### Test with HTTP mode:
```bash
# Start server in HTTP mode for testing
ruby bin/mcp_server.rb http 8080
```

## 🔧 Troubleshooting

### Common Issues:

1. **"Tool not found"** - Check MCP server is running and configured correctly
2. **"Authentication required"** - Verify API key is set in environment
3. **"No sets found"** - Log some workout data first
4. **Server won't start** - Check Rails dependencies and database migrations

### Debug Commands:
```bash
# Check if server registers tools
ruby bin/mcp_server.rb

# Test API key works
rails console
> ApiKey.find_by_key("c52fea4b46bcad9f8c692715179dd386")

# Check audit logs
rails console
> McpAuditLog.recent.limit(10)
```

## 🎯 Next Steps

Once you have the MCP server working:

1. **Create your own API key** through the web dashboard
2. **Add more workout data** to test the tools
3. **Explore the audit logs** to see usage tracking
4. **Try different exercises** and workout patterns

## 📚 Additional Resources

- **Web Dashboard**: http://localhost:3000/dashboard
- **API Documentation**: Available in the dashboard
- **Test User**: test@example.com / password123
- **API Key**: c52fea4b46bcad9f8c692715179dd386

Happy workout tracking! 🏋️‍♂️