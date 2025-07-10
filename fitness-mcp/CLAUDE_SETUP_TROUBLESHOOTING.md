# Claude Desktop MCP Setup Troubleshooting

## 🔧 Quick Fix Steps

### Step 1: Verify Configuration File
**Location**: `~/Library/Application Support/Claude/claude_desktop_config.json`

**Correct Content**:
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

**Check it exists**:
```bash
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### Step 2: Test MCP Server Manually
```bash
cd /Users/jeremywatt/Desktop/fitness-mcp/fitness-mcp
./start_mcp.sh
```

You should see:
```
I, [DATE]  INFO -- : Registered tool: LogSetTool
I, [DATE]  INFO -- : Registered tool: GetLastSetTool
I, [DATE]  INFO -- : Registered tool: GetLastSetsTool
I, [DATE]  INFO -- : Registered tool: GetRecentSetsTool
I, [DATE]  INFO -- : Registered tool: DeleteLastSetTool
I, [DATE]  INFO -- : Registered tool: AssignWorkoutTool
I, [DATE]  INFO -- : Starting STDIO transport
```

### Step 3: Restart Claude Desktop
1. **Completely close** Claude Desktop
2. **Wait 5 seconds**
3. **Reopen** Claude Desktop
4. **Wait for full startup**

### Step 4: Test Commands
Try these exact phrases in Claude Desktop:

```
Show me my recent workout history
```

```
What was my last bench press set?
```

```
Log a workout: squats, 225 lbs, 8 reps
```

## 🚨 Common Issues & Solutions

### Issue 1: "Config file empty or wrong"
**Solution**: Recreate the config file:
```bash
mkdir -p ~/Library/Application\ Support/Claude/
cat > ~/Library/Application\ Support/Claude/claude_desktop_config.json << 'EOF'
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
EOF
```

### Issue 2: "Script not executable"
**Solution**:
```bash
chmod +x /Users/jeremywatt/Desktop/fitness-mcp/fitness-mcp/start_mcp.sh
```

### Issue 3: "Ruby or Rails not found"
**Solution**: Make sure you're in the right directory and Rails is installed:
```bash
cd /Users/jeremywatt/Desktop/fitness-mcp/fitness-mcp
bundle install
rails --version
```

### Issue 4: "No tools visible in Claude"
**Solution**:
1. Check Claude Desktop version (newer versions work better)
2. Try typing fitness-related requests anyway
3. Look for subtle UI indicators (hammer icon, "using tools" text)
4. Try restarting Claude Desktop multiple times

### Issue 5: "Database errors"
**Solution**:
```bash
cd /Users/jeremywatt/Desktop/fitness-mcp/fitness-mcp
rails db:migrate
rails db:seed
```

## ✅ Verification Checklist

- [ ] Config file exists and has correct content
- [ ] Start script is executable (`-rwxr-xr-x`)
- [ ] MCP server starts without errors
- [ ] Claude Desktop has been restarted
- [ ] Test data exists (35 workout sets)
- [ ] API key is valid: `c52fea4b46bcad9f8c692715179dd386`

## 🎯 Testing Commands

Once everything is working, try these commands in Claude Desktop:

### Basic Tests
- "Show me my workout history"
- "What exercises have I done recently?"
- "Get my last bench press set"

### Advanced Tests
- "Show me my 10 most recent sets across all exercises"
- "Log a new set: deadlift, 315 lbs, 5 reps"
- "Delete my last workout entry"

### Data Verification
- "How many different exercises have I logged?"
- "What was my heaviest deadlift?"
- "Show me all my workouts from this week"

## 🔍 Debug Commands

### Check Config File
```bash
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### Test MCP Server
```bash
cd /Users/jeremywatt/Desktop/fitness-mcp/fitness-mcp
API_KEY="c52fea4b46bcad9f8c692715179dd386" ruby bin/mcp_server.rb stdio
```

### Check Database
```bash
rails console
> User.find_by(email: 'test@example.com').set_entries.count
> McpAuditLog.count
```

### Verify Sample Data
```bash
rails console
> User.find_by(email: 'test@example.com').set_entries.recent.limit(5)
```

## 📱 Claude Desktop UI Notes

Different versions show MCP differently:
- **Hammer icon** 🔨 in toolbar
- **"Using tools..."** text during requests  
- **Tool usage indicators** in chat
- **No visible indicator** but tools work silently

**Key**: Just ask natural language fitness questions - Claude will use tools automatically!

## 🆘 Still Not Working?

1. **Check Claude Desktop version** - Newer versions work better
2. **Try other MCP servers** - Test if MCP works at all
3. **Check system permissions** - Claude needs file access
4. **Try different phrasing** - "fitness", "workout", "exercise" keywords
5. **Look at logs** - MCP server terminal shows activity

## 📞 Getting Help

If still having issues:
1. Share the exact error messages
2. Show your config file content  
3. Show MCP server startup logs
4. Mention your Claude Desktop version
5. Try the web dashboard as fallback: http://localhost:3000/dashboard