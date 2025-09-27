# Project variables
APP_NAME = nasa-exoplanet-django
DOCKERFILE = Dockerfile
PORT = 8000

# Build the Docker image
build:
	docker build -t $(APP_NAME) -f $(DOCKERFILE) .

# Run the container (fresh each time)
run:
	docker run --rm -it -p $(PORT):8000 $(APP_NAME) ./setup.sh

# Start container in background
up:
	docker run -d -p $(PORT):8000 --name $(APP_NAME)-container $(APP_NAME) ./setup.sh

# Stop and remove container
down:
	docker stop $(APP_NAME)-container || true && docker rm $(APP_NAME)-container || true

# Clean up dangling images
clean:
	docker system prune -f

# Rebuild and run fresh
restart: down build up
