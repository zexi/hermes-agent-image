HERMES_GIT_REF ?= v2026.4.16
IMAGE_TAG ?= 20260417.3
BASE_IMAGE_TAG ?= 20260417.0

HERMES_AGENT_DIR := ./hermes-agent

.PHONY: checkout build build-base

# Update hermes-agent checkout to match $(HERMES_GIT_REF) before building the base image.
checkout:
	cd $(HERMES_AGENT_DIR) && git fetch --tags --prune && git checkout $(HERMES_GIT_REF)

build:
	docker buildx build --platform linux/amd64 --push \
		--build-arg BASE_IMAGE=registry.cn-beijing.aliyuncs.com/zexi/hermes-base:$(HERMES_GIT_REF)-$(BASE_IMAGE_TAG) \
		-t registry.cn-beijing.aliyuncs.com/zexi/hermes:$(HERMES_GIT_REF)-$(IMAGE_TAG) \
		-f Dockerfile.ubuntu .

build-base: checkout
	docker buildx build --platform linux/amd64 --push \
		-t registry.cn-beijing.aliyuncs.com/zexi/hermes-base:$(HERMES_GIT_REF)-$(BASE_IMAGE_TAG) \
		-f Dockerfile.ubuntu-base $(HERMES_AGENT_DIR)
