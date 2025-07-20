# Google OAuth Integration Todo List

## Phase 1: Database Schema & Dependencies

### Database Migration
- [ ] Create migration: `rails generate migration AddOAuthFieldsToUsers`
- [ ] Add `provider` column (string, nullable)
- [ ] Add `uid` column (string, nullable) 
- [ ] Add `name` column (string, nullable)
- [ ] Add `image_url` column (string, nullable)
- [ ] Add composite index on `[provider, uid]`
- [ ] Run migration: `rails db:migrate`

### Gem Installation
- [ ] Add `gem 'omniauth', '~> 2.1'` to Gemfile
- [ ] Add `gem 'omniauth-google-oauth2', '~> 1.1'` to Gemfile
- [ ] Add `gem 'omniauth-rails_csrf_protection', '~> 1.0'` to Gemfile
- [ ] Run `bundle install`

## Phase 2: OAuth Configuration

### Google Console Setup
- [ ] Create OAuth 2.0 credentials in Google Cloud Console
- [ ] Set authorized redirect URI: `http://localhost:3000/auth/google_oauth2/callback`
- [ ] Note client ID and client secret

### Rails Configuration
- [ ] Add Google OAuth credentials to Rails credentials:
  ```
  google:
    client_id: your_client_id
    client_secret: your_client_secret
  ```
- [ ] Create `config/initializers/omniauth.rb`
- [ ] Configure OmniAuth middleware with Google provider
- [ ] Add CSRF protection configuration

## Phase 3: Model Updates

### User Model Enhancements
- [ ] Add `from_omniauth(auth)` class method to User model
- [ ] Implement find_or_create logic with email matching
- [ ] Make `has_secure_password` conditional: `has_secure_password validations: false`
- [ ] Update password presence validation to be conditional
- [ ] Add method to check if user is OAuth user: `oauth_user?`
- [ ] Add method to check if user has password: `has_password?`

## Phase 4: Controllers & Routes

### Routes Configuration
- [ ] Add OmniAuth routes to `config/routes.rb`:
  - `get '/auth/:provider/callback', to: 'omniauth_callbacks#google'`
  - `get '/auth/failure', to: 'omniauth_callbacks#failure'`
- [ ] Keep existing auth routes intact

### OmniAuth Callbacks Controller
- [ ] Create `app/controllers/omniauth_callbacks_controller.rb`
- [ ] Implement `google` action for OAuth callback
- [ ] Handle successful authentication
- [ ] Handle account linking for existing email users
- [ ] Implement `failure` action for OAuth errors
- [ ] Set proper session variables

### Update Existing Controllers
- [ ] Update `WebSessionsController` to handle OAuth users
- [ ] Update `WebUsersController` registration logic
- [ ] Ensure password resets work only for non-OAuth users
- [ ] Update `ApplicationController` authentication helpers

## Phase 5: Views & UI

### Login Page Updates
- [ ] Add "Sign in with Google" button to `app/views/web_sessions/new.html.erb`
- [ ] Style OAuth button appropriately
- [ ] Add divider between OAuth and email login

### Registration Page Updates
- [ ] Add "Sign up with Google" button to `app/views/web_users/new.html.erb`
- [ ] Update form to show OAuth option
- [ ] Maintain existing email registration form

### Dashboard Updates
- [ ] Show authentication method in user dashboard
- [ ] Display Google profile picture if available
- [ ] Add account linking section for email users
- [ ] Add unlink option for users with both auth methods

### Account Settings
- [ ] Create account settings page if not exists
- [ ] Add Google account linking/unlinking functionality
- [ ] Show connected accounts status

## Phase 6: Security & Error Handling

### Security Measures
- [ ] Verify CSRF protection is working
- [ ] Implement state parameter validation
- [ ] Add rate limiting for OAuth callbacks
- [ ] Secure handling of OAuth tokens

### Error Handling
- [ ] Handle OAuth authentication failures gracefully
- [ ] Add flash messages for OAuth errors
- [ ] Implement fallback for network issues
- [ ] Log OAuth errors appropriately

## Phase 7: Testing

### Manual Testing Scenarios
- [ ] Test new user registration via Google
- [ ] Test existing email user login via Google (auto-link)
- [ ] Test login with non-matching Google email
- [ ] Test switching between auth methods
- [ ] Test API key generation for OAuth users
- [ ] Test logout functionality
- [ ] Test account linking/unlinking

### Automated Tests
- [ ] Write tests for `User.from_omniauth` method
- [ ] Write controller tests for OAuth callbacks
- [ ] Test OAuth failure scenarios
- [ ] Test account linking logic
- [ ] Update existing auth tests to handle OAuth users

## Phase 8: Documentation & Deployment

### Documentation
- [ ] Update README with Google OAuth setup instructions
- [ ] Document environment variables needed
- [ ] Add OAuth flow diagram
- [ ] Document account linking behavior

### Production Considerations
- [ ] Update production OAuth redirect URIs
- [ ] Ensure HTTPS is used in production
- [ ] Set up production Google OAuth credentials
- [ ] Test OAuth flow in staging environment

## Completion Checklist
- [ ] All existing users can still login with email/password
- [ ] New users can register with Google
- [ ] Existing users can link Google accounts
- [ ] API authentication still works unchanged
- [ ] All tests pass
- [ ] Security measures implemented
- [ ] Documentation updated
- [ ] Production ready

## Notes
- Priority: Maintain backward compatibility
- Email matching enables seamless migration
- Keep API auth separate from OAuth
- Focus on user experience for account linking