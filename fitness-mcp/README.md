# Fitness MCP Server

A Ruby on Rails 8 application for fitness tracking with Model Context Protocol (MCP) integration and Google OAuth authentication.

## Features

- **User Authentication**: 
  - Traditional email/password authentication
  - Google OAuth integration (new!)
  - Seamless account linking for existing users
- **API Key Management**: Secure API key generation and management
- **Fitness Tracking**: Log workouts, track progress, view history
- **MCP Integration**: AI-powered workout planning and insights
- **RESTful API**: Full API for programmatic access

## System Requirements

- Ruby 3.x
- Rails 8.0.2+
- SQLite3 (development) or PostgreSQL (production)
- Node.js (for asset compilation)

## Google OAuth Setup

The application now supports Google OAuth for user authentication. See [GOOGLE_OAUTH_SETUP.md](GOOGLE_OAUTH_SETUP.md) for detailed setup instructions.

### Quick Setup:

1. Create Google OAuth credentials in Google Cloud Console
2. Add credentials to Rails:
   ```bash
   EDITOR="code --wait" bin/rails credentials:edit
   ```
   Add:
   ```yaml
   google:
     client_id: YOUR_CLIENT_ID
     client_secret: YOUR_CLIENT_SECRET
   ```
3. Users can now sign in/up with Google!

## Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   ```
3. Setup database:
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   ```
4. Start the server:
   ```bash
   bin/rails server
   ```

## Configuration

- **OAuth Providers**: Configure in `config/initializers/omniauth.rb`
- **API Settings**: Managed through environment variables
- **MCP Server**: Configure in `config/mcp_server.rb`

## Testing

Run the test suite:
```bash
bin/rails test
```

Run specific test files:
```bash
bin/rails test test/models/user_oauth_test.rb
```

## API Documentation

Visit `/api_info` when the server is running for complete API documentation.

## Deployment

See deployment guide for production setup instructions, including:
- Setting up OAuth redirect URIs
- Configuring HTTPS
- Environment-specific credentials
