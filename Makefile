VERSION ?= latest

DOCKERFILE := Dockerfile
IMAGE_NAME := crystal-xbuild

.PHONY: build
build: $(DOCKERFILE)
	docker build -t ${IMAGE_NAME}:${VERSION} -f ${DOCKERFILE} .
