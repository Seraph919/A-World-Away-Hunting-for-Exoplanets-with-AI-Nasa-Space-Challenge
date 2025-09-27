APP_NAME = nasa-exoplanet-django
DOCKERFILE = Dockerfile
PORT = 8000

build:
	docker build -t $(APP_NAME) -f $(DOCKERFILE) .

run:
	docker run --rm -it -p $(PORT):8000 $(APP_NAME) ./setup.sh

up:
	docker run -d -p $(PORT):8000 --name $(APP_NAME)-container $(APP_NAME) ./setup.sh

down:
	docker stop $(APP_NAME)-container || true && docker rm $(APP_NAME)-container || true

clean:
	docker system prune -f

restart: down build up
