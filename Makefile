UNAME_M = $(shell uname -m)
ARCH=
ifeq ($(UNAME_M), x86_64)
	ARCH=amd64
else
	ARCH=$(UNAME_M)
endif

SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t rancher/etcd:$(TAG)-$(ARCH) .

.PHONY: image-push
image-push:
	docker push rancher/etcd:$(TAG)-$(ARCH)

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed rancher/etcd:$(TAG)-$(ARCH)

.PHONY: image-manifest
image-manifest:
	docker image inspect rancher/etcd:$(TAG)-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create rancher/etcd:$(TAG)-$(ARCH) \
		$(shell docker image inspect rancher/etcd:$(TAG)-$(ARCH) | jq -r '.[] | .RepoDigests[0]')
