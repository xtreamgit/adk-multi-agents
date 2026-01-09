# Docker Deployment Guide

This guide explains how to run the USFS-RAG application using Docker containers.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 4GB RAM available for containers

## Quick Start

1. **Clone and navigate to the repository:**
   ```bash
   cd adk-rag-agent
   ```

2. **Set environment variables (optional):**
   ```bash
   export SECRET_KEY="your-secure-secret-key-here"
   ```

3. **Build and run with Docker Compose:**
   ```bash
   docker-compose up --build
   ```

4. **Access the application:**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000
   - API Documentation: http://localhost:8000/docs

## Architecture

The application consists of two main services:

### Backend Service
- **Port:** 8000
- **Technology:** FastAPI + Python 3.11
- **Database:** SQLite (persistent volume)
- **Features:** JWT authentication, RAG agent, session management

### Frontend Service
- **Port:** 3000
- **Technology:** Next.js 15 + React 19
- **Features:** Modern UI, authentication, chat interface

## Configuration

### Environment Variables

#### Backend
- `SECRET_KEY`: JWT signing key (default: "your-secret-key-change-in-production")
- `DATABASE_PATH`: SQLite database path (default: "/app/data/users.db")
- `LOG_LEVEL`: Logging level (default: "INFO")
- `ENVIRONMENT`: Runtime environment (default: "production")

#### Frontend
- `NODE_ENV`: Node environment (default: "production")
- `NEXT_TELEMETRY_DISABLED`: Disable Next.js telemetry (default: "1")

### Custom Configuration

Create a `.env` file in the root directory:
```env
SECRET_KEY=your-very-secure-secret-key-here
LOG_LEVEL=DEBUG
```

## Docker Commands

### Development
```bash
# Build and run in development mode
docker-compose up --build

# Run in background
docker-compose up -d --build

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Production
```bash
# Build for production
docker-compose -f docker-compose.yml up --build -d

# Scale services (if needed)
docker-compose up --scale frontend=2 -d
```

### Maintenance
```bash
# Restart services
docker-compose restart

# Update images
docker-compose pull
docker-compose up -d

# Clean up
docker-compose down -v  # Removes volumes (WARNING: deletes data)
docker system prune -a  # Clean up unused images
```

## Data Persistence

- **User Database:** Stored in `backend_data` Docker volume
- **Location:** `/app/data/users.db` inside container
- **Backup:** Use `docker cp` to backup the database file

### Backup Database
```bash
# Create backup
docker cp $(docker-compose ps -q backend):/app/data/users.db ./backup-users.db

# Restore backup
docker cp ./backup-users.db $(docker-compose ps -q backend):/app/data/users.db
```

## Troubleshooting

### Common Issues

1. **Port conflicts:**
   ```bash
   # Check what's using the ports
   lsof -i :3000
   lsof -i :8000
   
   # Kill processes or change ports in docker-compose.yml
   ```

2. **Permission issues:**
   ```bash
   # Fix file permissions
   sudo chown -R $USER:$USER .
   ```

3. **Memory issues:**
   ```bash
   # Check Docker memory usage
   docker stats
   
   # Increase Docker memory limit in Docker Desktop
   ```

4. **Database issues:**
   ```bash
   # Reset database (WARNING: deletes all data)
   docker-compose down -v
   docker-compose up --build
   ```

### Logs and Debugging

```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs backend
docker-compose logs frontend

# Follow logs in real-time
docker-compose logs -f backend

# Execute commands in running container
docker-compose exec backend bash
docker-compose exec frontend sh
```

## Health Checks

The backend service includes health checks:
- **Endpoint:** `GET /`
- **Interval:** 30 seconds
- **Timeout:** 10 seconds
- **Retries:** 3

Monitor health status:
```bash
docker-compose ps
```

## Security Considerations

1. **Change default secrets:**
   - Set a strong `SECRET_KEY` environment variable
   - Use environment-specific configuration

2. **Network security:**
   - Services communicate via internal Docker network
   - Only necessary ports are exposed

3. **File permissions:**
   - Frontend runs as non-root user (nextjs:nodejs)
   - Backend creates dedicated data directory

## Performance Optimization

1. **Multi-stage builds:** Both Dockerfiles use multi-stage builds for smaller images
2. **Layer caching:** Dependencies are installed before copying source code
3. **Production builds:** Frontend uses Next.js standalone output for optimal performance

## Monitoring

Monitor the application using Docker commands:
```bash
# Resource usage
docker stats

# Container health
docker-compose ps

# Service logs
docker-compose logs -f
```

For production deployments, consider adding:
- Prometheus metrics
- Log aggregation (ELK stack)
- Container orchestration (Kubernetes)
