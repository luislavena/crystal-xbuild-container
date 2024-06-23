VERSION ?= latest

DOCKERFILE := Dockerfile
IMAGE_NAME := crystal-xbuild

.PHONY: build
build: $(DOCKERFILE)
	docker build -t ${IMAGE_NAME}:${VERSION} -f ${DOCKERFILE} .

.PHONY: run
run: $(DOCKERFILE)
	docker run -it --rm -v .:/app -w /app ${IMAGE_NAME}:${VERSION} sh -i
