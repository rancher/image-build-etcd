SEVERITIES = HIGH,CRITICAL
VEX_REPORT = .rancher.openvex.json
VEX_REPORT_COMMIT = $(VEX_REPORT).commit
VEX_REPORT_PATH = reports/rancher.openvex.json

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
	new_commit="$$(gh api "repos/rancher/vexhub/commits?path=$(VEX_REPORT_PATH)&per_page=1" --jq '.[0].sha')"; \
	stored_commit="$$(cat "$(VEX_REPORT_COMMIT)" 2>/dev/null || true)"; \
	if [ "$$new_commit" != "$$stored_commit" ] || [ ! -f "$(VEX_REPORT)" ] || \
		grep -q '^version https://git-lfs.github.com/spec/v1$$' "$(VEX_REPORT)"; then \
		download_url="$$(gh api "repos/rancher/vexhub/contents/$(VEX_REPORT_PATH)?ref=main" --jq '.download_url')"; \
		gh api "$$download_url" > "$(VEX_REPORT)"; \
		printf '%s\n' "$$new_commit" > "$(VEX_REPORT_COMMIT)"; \
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
