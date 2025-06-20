#!/bin/bash

set -e

echo "⚡️ Setting up your private SearXNG instance ⚡️"

# Check Docker installation
command -v docker >/dev/null 2>&1 || { echo >&2 "Docker is not installed. Please install Docker first."; exit 1; }

# Get user input
read -rp "Enter your domain (e.g., search.example.com) [leave empty for localhost]: " domain
domain=${domain:-localhost}

read -rp "Enter the port you want SearXNG to run on [default 8080]: " port
port=${port:-8080}

read -rp "Number of UWSGI Workers [default 4]: " workers
workers=${workers:-4}

read -rp "Number of UWSGI Threads [default 4]: " threads
threads=${threads:-4}

# Determine base_url and query_url
if [ "$domain" = "localhost" ]; then
    base_url="http://localhost/"
    query_url="http://localhost:$port/search?q=<query>"
else
    base_url="https://$domain/"
    query_url="http://$domain/search?q=<query>"
fi

# Create .env
cat <<EOF > .env
SEARXNG_HOSTNAME=$domain
SEARXNG_UWSGI_WORKERS=$workers
SEARXNG_UWSGI_THREADS=$threads
EOF

# Ensure config directory
mkdir -p ./searxng

# Create docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  redis:
    container_name: redis
    image: docker.io/valkey/valkey:8-alpine
    command: valkey-server --save 30 1 --loglevel warning --maxmemory 128mb --maxmemory-policy allkeys-lru
    restart: unless-stopped
    networks:
      - searxng
    volumes:
      - valkey-data2:/data
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "1"

  searxng:
    container_name: searxng
    image: docker.io/searxng/searxng:latest
    restart: unless-stopped
    depends_on:
      - redis
    networks:
      - searxng
    ports:
      - "0.0.0.0:$port:8080"
    volumes:
      - ./searxng:/etc/searxng:rw
    environment:
      - SEARXNG_BASE_URL=$base_url
      - UWSGI_WORKERS=$workers
      - UWSGI_THREADS=$threads
      - SEARXNG_REDIS_URL=redis://redis:6379/0
      - ENABLE_RAG_WEB_SEARCH=True
      - RAG_WEB_SEARCH_ENGINE=searxng
      - RAG_WEB_SEARCH_RESULT_COUNT=3
      - RAG_WEB_SEARCH_CONCURRENT_REQUESTS=10
      - SEARXNG_QUERY_URL=$query_url
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "1"

networks:
  searxng:
    name: searxng-network
    driver: bridge

volumes:
  valkey-data2:
    name: valkey-storage
EOF

# Run Docker Compose
echo "🚀 Starting your SearXNG instance on port $port..."
docker compose up -d

sleep 3

# Check if container is running
if docker compose ps | grep -q "searxng.*Up"; then
    local_ip=$(hostname -I | awk '{print $1}')
    if [ "$domain" = "localhost" ]; then
        user_url="http://$local_ip:$port"
    else
        user_url="https://$domain"
    fi

    echo "✅ SearXNG is up and running successfully!"
    echo
    echo "🌐 URLs to access your instance:"
    echo "➜ Final URL (user): $user_url"
    echo "➜ Direct local access: http://$local_ip:$port"
else
    echo "❌ Something went wrong. Check logs with 'docker compose logs'"
fi

echo ""
echo "🌟 malkhatib YouTube channel 🌟"
echo "https://www.youtube.com/@malkhatib"
