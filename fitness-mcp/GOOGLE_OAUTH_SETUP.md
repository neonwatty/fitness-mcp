# Google OAuth Setup Guide

This guide explains how to set up Google OAuth authentication for the Fitness MCP Rails application.

## Prerequisites

- Ruby on Rails 8 application
- Google Cloud Console account
- Access to Rails credentials

## Google Cloud Console Setup

1. **Create a new project** (or use existing):
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Create a new project or select an existing one

2. **Enable Google+ API**:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Google+ API"
   - Click on it and press "Enable"

3. **Create OAuth 2.0 Credentials**:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "OAuth client ID"
   - Configure OAuth consent screen if prompted:
     - Choose "External" for public apps
     - Fill in required fields (app name, support email, etc.)
     - Add your domain to authorized domains
   - For Application type, select "Web application"
   - Add authorized redirect URIs:
     - Development: `http://localhost:3000/auth/google_oauth2/callback`
     - Production: `https://yourdomain.com/auth/google_oauth2/callback`
   - Save and note down your Client ID and Client Secret

## Rails Application Configuration

### 1. Update Rails Credentials

Edit your Rails credentials:

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

Add your Google OAuth credentials:

```yaml
google:
  client_id: YOUR_GOOGLE_CLIENT_ID
  client_secret: YOUR_GOOGLE_CLIENT_SECRET
```

### 2. Environment-Specific Configuration

For different environments, you can use environment-specific credentials:

```bash
# Development
EDITOR="code --wait" bin/rails credentials:edit --environment development

# Production
EDITOR="code --wait" bin/rails credentials:edit --environment production
```

## Features Implemented

### 1. User Authentication Flow

- **New Users**: Can sign up using Google account
- **Existing Users**: Automatically linked if email matches
- **Mixed Authentication**: Users can use either Google or email/password

### 2. Account Linking

- Users who registered with email/password can link their Google account
- Prevents duplicate accounts with same email
- Seamless migration for existing users

### 3. User Interface

- "Sign in with Google" button on login page
- "Sign up with Google" button on registration page
- User dashboard shows authentication method
- Profile picture from Google displayed when available

### 4. Security Features

- CSRF protection via `omniauth-rails_csrf_protection`
- OAuth state parameter validation
- Secure session handling
- Clear error messages for failed authentication

## Database Schema

The following fields were added to the users table:

- `provider` (string) - OAuth provider name (e.g., "google_oauth2")
- `uid` (string) - Unique identifier from OAuth provider
- `name` (string) - User's full name from OAuth
- `image_url` (string) - Profile picture URL
- Composite index on `[provider, uid]` for fast lookups

## User Model Enhancements

### Key Methods

- `User.from_omniauth(auth)` - Find or create user from OAuth data
- `user.oauth_user?` - Check if user authenticated via OAuth
- `user.has_password?` - Check if user has a password set

### Validation Changes

- Password is optional for OAuth users
- Email remains required and unique
- Conditional password validation based on authentication type

## Testing

Run OAuth-specific tests:

```bash
bin/rails test test/models/user_oauth_test.rb
bin/rails test test/controllers/omniauth_callbacks_controller_test.rb
```

## Deployment Considerations

### 1. Production OAuth Setup

- Update redirect URI in Google Console to production URL
- Use HTTPS for all OAuth callbacks
- Set production credentials in Rails

### 2. Environment Variables (Alternative)

Instead of Rails credentials, you can use environment variables:

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV['GOOGLE_CLIENT_ID'],
           ENV['GOOGLE_CLIENT_SECRET'],
           {
             scope: 'email,profile',
             prompt: 'select_account'
           }
end
```

### 3. Session Security

Ensure your session configuration is secure:

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
  key: '_fitness_mcp_session',
  secure: Rails.env.production?, # HTTPS only in production
  httponly: true,
  same_site: :lax
```

## Troubleshooting

### Common Issues

1. **"Invalid credentials" error**:
   - Verify Client ID and Secret are correct
   - Check redirect URI matches exactly
   - Ensure Google+ API is enabled

2. **"Access blocked" error**:
   - Complete OAuth consent screen setup
   - Add test users if app is in testing mode
   - Verify domain is authorized

3. **Session not persisting**:
   - Check cookie settings
   - Verify CSRF token is included
   - Ensure session middleware is loaded

### Debug Mode

Enable OmniAuth debug logging:

```ruby
# config/initializers/omniauth.rb
OmniAuth.config.logger = Rails.logger
OmniAuth.config.on_failure = Proc.new { |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}
```

## API Integration

OAuth users can still use API authentication:

1. Login via Google OAuth
2. Generate API key from dashboard
3. Use API key for programmatic access

The API authentication remains separate from OAuth, maintaining backward compatibility.

## Future Enhancements

Consider implementing:

1. Additional OAuth providers (GitHub, Facebook, etc.)
2. Two-factor authentication
3. OAuth token refresh for extended sessions
4. Account unlinking functionality
5. Social profile data synchronization