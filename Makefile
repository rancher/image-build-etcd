SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t rancher/hardened-etcd:$(TAG) .

.PHONY: image-push
image-push:
	docker push rancher/hardened-etcd:$(TAG)

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed rancher/hardened-etcd:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect rancher/hardened-etcd:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create rancher/hardened-etcd:$(TAG) \
		$(shell docker image inspect rancher/hardened-etcd:$(TAG) | jq -r '.[] | .RepoDigests[0]')
