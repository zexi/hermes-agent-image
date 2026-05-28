HERMES_GIT_REF ?= v2026.5.16
IMAGE_TAG ?= 20260527.1
BASE_IMAGE_TAG ?= 20260525.0

# Set SKIP_CHECKOUT=1 to build-base against the current hermes-agent working
# tree without running `git fetch` + `git checkout $(HERMES_GIT_REF)` first.
# Useful for iterating on local changes inside hermes-agent/.
SKIP_CHECKOUT ?=

HERMES_AGENT_DIR := ./hermes-agent

ifeq ($(SKIP_CHECKOUT),)
BASE_DEPS := checkout
else
BASE_DEPS :=
endif

.PHONY: checkout build build-base

# Update hermes-agent checkout to match $(HERMES_GIT_REF) before building the base image.
checkout:
	cd $(HERMES_AGENT_DIR) && git fetch --tags --prune && git checkout $(HERMES_GIT_REF)

build:
	docker buildx build --platform linux/amd64 --push \
		--build-arg BASE_IMAGE=registry.cn-beijing.aliyuncs.com/zexi/hermes-base:$(HERMES_GIT_REF)-$(BASE_IMAGE_TAG) \
		-t registry.cn-beijing.aliyuncs.com/zexi/hermes:$(HERMES_GIT_REF)-$(IMAGE_TAG) \
		-f Dockerfile.ubuntu .

build-base: $(BASE_DEPS)
	docker buildx build --platform linux/amd64 --push \
		-t registry.cn-beijing.aliyuncs.com/zexi/hermes-base:$(HERMES_GIT_REF)-$(BASE_IMAGE_TAG) \
		-f Dockerfile.ubuntu-base $(HERMES_AGENT_DIR)
