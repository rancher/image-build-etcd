SEVERITIES = HIGH,CRITICAL
VEX_REPORT = .rancher.openvex.json
VEX_REPORT_META = .rancher.openvex.json.meta
VEX_REPORT_META_URL = https://raw.githubusercontent.com/rancher/vexhub/refs/heads/main/reports/rancher.openvex.json
VEX_REPORT_URL = https://github.com/rancher/vexhub/raw/refs/heads/main/reports/rancher.openvex.json

UNAME_M = $(shell uname -m)
ifndef TARGET_PLATFORMS
	ifeq ($(UNAME_M), x86_64)
		TARGET_PLATFORMS:=linux/amd64
	else ifeq ($(UNAME_M), aarch64)
		TARGET_PLATFORMS:=linux/arm64
	else 
		TARGET_PLATFORMS:=linux/$(UNAME_M)
	endif
endif

BUILD_META=-build$(shell date +%Y%m%d)
TAG ?= ${GITHUB_ACTION_TAG}

ifeq ($(TAG),)
TAG := $(shell head -n 1 TAG)$(BUILD_META)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG needs to end with build metadata: $(BUILD_META))
endif

REPO ?= rancher
IMAGE = $(REPO)/hardened-etcd:$(TAG)
BUILD_OPTS = \
	--platform=$(TARGET_PLATFORMS) \
	--build-arg TAG=$(TAG:$(BUILD_META)=) \
	--build-arg ETCD_UNSUPPORTED_ARCH=$(ETCD_UNSUPPORTED_ARCH) \
	--tag "$(IMAGE)"

.PHONY: image-build
image-build:
	docker buildx build \
		$(BUILD_OPTS) \
		--pull \
		--load \
	.

.PHONY: push-image
push-image:
	docker buildx build \
		$(BUILD_OPTS) \
		$(IID_FILE_FLAG) \
		$(BUILDX_ARGS) \
		--push \
		.

.PHONY: push-prime-image
push-prime-image:
	BUILDX_ARGS="--sbom=true --attest type=provenance,mode=max" \
	$(MAKE) push-image

.PHONY: image-scan
image-scan:
	@set -eu; \
	remote_sha="$$(curl --fail --silent --show-error --location "$(VEX_REPORT_META_URL)" | sha256sum | awk '{print $$1}')"; \
	local_sha="$$(sha256sum "$(VEX_REPORT_META)" 2>/dev/null | awk '{print $$1}' || true)"; \
	if [ "$$remote_sha" != "$$local_sha" ]; then \
		curl --fail --silent --show-error --location "$(VEX_REPORT_URL)" > "$(VEX_REPORT)"; \
		curl --fail --silent --show-error --location "$(VEX_REPORT_META_URL)" > "$(VEX_REPORT_META)"; \
	fi
	trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed --vex "$(VEX_REPORT)" $(IMAGE)

PHONY: log
log:
	@echo "TAG=$(TAG:$(BUILD_META)=)"
	@echo "REPO=$(REPO)"
	@echo "IMAGE=$(IMAGE)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"
	@echo "TARGET_PLATFORMS=$(TARGET_PLATFORMS)"
