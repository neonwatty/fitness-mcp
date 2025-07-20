# Docker Production Deployment Guide

This guide covers deploying the Fitness MCP application using Docker.

## Prerequisites

- Docker installed on your system
- Google OAuth credentials (see [GOOGLE_OAUTH_SETUP.md](GOOGLE_OAUTH_SETUP.md))
- Rails master key (from `config/master.key`)

## Environment Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and set:
   - `SECRET_KEY_BASE` - Generate with `rails secret`
   - `GOOGLE_CLIENT_ID` - Your Google OAuth client ID
   - `GOOGLE_CLIENT_SECRET` - Your Google OAuth client secret
   - `APP_HOST` - Your production domain (e.g., https://fitness.yourdomain.com)

## Building the Docker Image

```bash
# Build the production image
docker build -t fitness-mcp:latest .

# Or with build arguments
docker build \
  --build-arg RUBY_VERSION=3.4.2 \
  -t fitness-mcp:latest .
```

## Running the Container

### Basic Run Command

```bash
docker run -d \
  -p 80:80 \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  --env-file .env \
  --name fitness-mcp \
  fitness-mcp:latest
```

### With Volume Mounts (for persistent storage)

```bash
docker run -d \
  -p 80:80 \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  --env-file .env \
  -v fitness-storage:/rails/storage \
  -v fitness-db:/rails/db \
  --name fitness-mcp \
  fitness-mcp:latest
```

## Docker Compose (Alternative)

Create a `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "80:80"
    environment:
      - RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
    env_file:
      - .env
    volumes:
      - storage:/rails/storage
      - db:/rails/db
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/up"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 60s

volumes:
  storage:
  db:
```

Then run:
```bash
RAILS_MASTER_KEY=$(cat config/master.key) docker-compose up -d
```

## Health Monitoring

The container includes a health check that monitors the `/up` endpoint. Check container health:

```bash
docker ps
docker inspect fitness-mcp --format='{{.State.Health.Status}}'
```

## Logs

View application logs:
```bash
docker logs fitness-mcp
docker logs -f fitness-mcp  # Follow logs
```

## Database Management

Run database migrations:
```bash
docker exec fitness-mcp rails db:migrate
```

Access Rails console:
```bash
docker exec -it fitness-mcp rails console
```

## Updating the Application

1. Pull latest code changes
2. Rebuild the image: `docker build -t fitness-mcp:latest .`
3. Stop old container: `docker stop fitness-mcp && docker rm fitness-mcp`
4. Start new container with the run command above

## Troubleshooting

### Assets Not Loading
- Ensure `RAILS_SERVE_STATIC_FILES=true` is set in production
- Check that assets were precompiled during build

### OAuth Not Working
- Verify `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set
- Check that redirect URIs in Google Console include your production domain
- Ensure `APP_HOST` matches your actual domain

### Database Issues
- For persistent data, use volume mounts
- Run migrations after container starts: `docker exec fitness-mcp rails db:migrate`

### Container Won't Start
- Check logs: `docker logs fitness-mcp`
- Verify all required environment variables are set
- Ensure ports are not already in use

## Security Considerations

- Always use HTTPS in production (configure reverse proxy)
- Keep `RAILS_MASTER_KEY` secure and never commit it
- Regularly update base images for security patches
- Use secrets management for sensitive environment variables
- Enable rate limiting on your reverse proxy