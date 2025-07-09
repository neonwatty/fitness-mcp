# Fitness MCP Server API Documentation

## Overview
The Fitness MCP Server provides both REST API endpoints and Model Context Protocol (MCP) integration for fitness tracking and workout planning.

## Base URL
```
http://localhost:3000/api/v1
```

## Authentication
Most endpoints require API key authentication via the `Authorization` header:
```
Authorization: Bearer YOUR_API_KEY_HERE
```

## Endpoints

### 1. User Registration
**POST /api/v1/users**

Create a new user account.

**Request Body:**
```json
{
  "user": {
    "email": "user@example.com",
    "password": "securepassword",
    "password_confirmation": "securepassword"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "User created successfully",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "created_at": "2025-01-01T00:00:00Z"
  }
}
```

### 2. Session Management

#### Login
**POST /api/v1/sessions**

Authenticate user and get API key.

**Request Body:**
```json
{
  "session": {
    "email": "user@example.com",
    "password": "securepassword",
    "name": "My Session Key"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Login successful",
  "user": {
    "id": 1,
    "email": "user@example.com"
  },
  "api_key": "your-generated-api-key",
  "key_name": "My Session Key"
}
```

#### Logout
**DELETE /api/v1/sessions**

Revoke current API key.

**Headers:**
```
Authorization: Bearer YOUR_API_KEY
```

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

### 3. API Key Management

#### List API Keys
**GET /api/v1/api_keys**

Get all active API keys for the authenticated user.

**Response:**
```json
{
  "success": true,
  "api_keys": [
    {
      "id": 1,
      "name": "My Session Key",
      "created_at": "2025-01-01T00:00:00Z",
      "revoked_at": null,
      "active": true
    }
  ]
}
```

#### Create API Key
**POST /api/v1/api_keys**

Create a new API key.

**Request Body:**
```json
{
  "api_key": {
    "name": "My New API Key"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "API key created successfully",
  "api_key": "your-new-api-key",
  "key_info": {
    "id": 2,
    "name": "My New API Key",
    "created_at": "2025-01-01T00:00:00Z",
    "revoked_at": null,
    "active": true
  }
}
```

#### Revoke API Key
**PATCH /api/v1/api_keys/:id/revoke**

Revoke a specific API key.

**Response:**
```json
{
  "success": true,
  "message": "API key revoked successfully"
}
```

#### Delete API Key
**DELETE /api/v1/api_keys/:id**

Delete a specific API key.

**Response:**
```json
{
  "success": true,
  "message": "API key deleted successfully"
}
```

### 4. Fitness Tracking Endpoints

#### Log a Set
**POST /api/v1/log_set**

Log a completed workout set.

**Request Body:**
```json
{
  "exercise": "barbell squat",
  "weight": 135.5,
  "reps": 12,
  "timestamp": "2025-01-01T10:00:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Successfully logged 12 reps of barbell squat at 135.5 lbs",
  "set_entry": {
    "id": 1,
    "exercise": "barbell squat",
    "weight": 135.5,
    "reps": 12,
    "timestamp": "2025-01-01T10:00:00Z"
  }
}
```

#### Get Last Set
**GET /api/v1/get_last_set?exercise=barbell%20squat**

Get the most recent set for a specific exercise.

**Response:**
```json
{
  "success": true,
  "message": "Last barbell squat: 12 reps at 135.5 lbs on 2025-01-01 10:00",
  "set_entry": {
    "id": 1,
    "exercise": "barbell squat",
    "weight": 135.5,
    "reps": 12,
    "timestamp": "2025-01-01T10:00:00Z"
  }
}
```

#### Get Last N Sets
**GET /api/v1/get_last_sets?exercise=barbell%20squat&limit=5**

Get the last N sets for a specific exercise.

**Response:**
```json
{
  "success": true,
  "message": "Found 3 recent sets for barbell squat",
  "count": 3,
  "set_entries": [
    {
      "id": 3,
      "exercise": "barbell squat",
      "weight": 135.5,
      "reps": 12,
      "timestamp": "2025-01-01T10:00:00Z"
    },
    {
      "id": 2,
      "exercise": "barbell squat",
      "weight": 135.0,
      "reps": 10,
      "timestamp": "2025-01-01T09:30:00Z"
    }
  ]
}
```

#### Delete Last Set
**DELETE /api/v1/delete_last_set?exercise=barbell%20squat**

Delete the most recent set for a specific exercise.

**Response:**
```json
{
  "success": true,
  "message": "Successfully deleted last barbell squat set: 12 reps at 135.5 lbs",
  "deleted_set": {
    "id": 1,
    "exercise": "barbell squat",
    "weight": 135.5,
    "reps": 12,
    "timestamp": "2025-01-01T10:00:00Z"
  }
}
```

#### Assign Workout
**POST /api/v1/assign_workout**

Create a structured workout assignment.

**Request Body:**
```json
{
  "assignment_name": "Push Day",
  "scheduled_for": "2025-01-02T09:00:00Z",
  "exercises": [
    {
      "name": "bench press",
      "sets": 3,
      "reps": 8,
      "weight": 185.0
    },
    {
      "name": "overhead press",
      "sets": 3,
      "reps": 10,
      "weight": 95.0
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Successfully created workout assignment 'Push Day' scheduled for 2025-01-02 09:00",
  "workout_assignment": {
    "id": 1,
    "assignment_name": "Push Day",
    "exercises": [
      {
        "name": "bench press",
        "sets": 3,
        "reps": 8,
        "weight": 185.0
      },
      {
        "name": "overhead press",
        "sets": 3,
        "reps": 10,
        "weight": 95.0
      }
    ],
    "scheduled_for": "2025-01-02T09:00:00Z"
  }
}
```

### 5. Full CRUD Endpoints

#### Set Entries
- **GET /api/v1/set_entries** - List all set entries (with pagination)
- **GET /api/v1/set_entries/:id** - Get specific set entry
- **POST /api/v1/set_entries** - Create new set entry
- **PATCH /api/v1/set_entries/:id** - Update set entry
- **DELETE /api/v1/set_entries/:id** - Delete set entry

#### Workout Assignments
- **GET /api/v1/workout_assignments** - List all workout assignments
- **GET /api/v1/workout_assignments/:id** - Get specific workout assignment
- **POST /api/v1/workout_assignments** - Create new workout assignment
- **PATCH /api/v1/workout_assignments/:id** - Update workout assignment
- **DELETE /api/v1/workout_assignments/:id** - Delete workout assignment

## Error Responses

All endpoints return error responses in this format:
```json
{
  "error": "Error message describing what went wrong"
}
```

Common HTTP status codes:
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `404` - Not Found
- `422` - Unprocessable Entity
- `500` - Internal Server Error

## MCP Integration

The server also provides MCP (Model Context Protocol) integration through:
- **STDIO Transport**: `ruby bin/mcp_server.rb stdio`
- **HTTP Transport**: `ruby bin/mcp_server.rb http [port]`

The MCP server exposes the same fitness tracking functionality as tools that can be called by LLMs and AI agents.

## Example Usage

### Complete Workflow Example

1. **Register a user:**
```bash
curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "lifter@example.com",
      "password": "strongpassword123",
      "password_confirmation": "strongpassword123"
    }
  }'
```

2. **Login to get API key:**
```bash
curl -X POST http://localhost:3000/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "session": {
      "email": "lifter@example.com",
      "password": "strongpassword123",
      "name": "My Workout Session"
    }
  }'
```

3. **Log a workout set:**
```bash
curl -X POST http://localhost:3000/api/v1/log_set \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "exercise": "deadlift",
    "weight": 225.0,
    "reps": 5
  }'
```

4. **Get workout history:**
```bash
curl "http://localhost:3000/api/v1/get_last_sets?exercise=deadlift&limit=10" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

## Rate Limiting

Currently, no rate limiting is implemented. Consider adding rate limiting for production use.

## Security

- All passwords are hashed using bcrypt
- API keys are stored as SHA256 hashes
- Use HTTPS in production
- API keys should be kept secure and rotated regularly