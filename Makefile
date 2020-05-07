SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t ranchertest/etcd:$(TAG) .

.PHONY: image-push
image-push:
	docker push ranchertest/etcd:$(TAG)

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed ranchertest/etcd:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect ranchertest/etcd:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create fips-image-build-flannel:$(TAG) \
		$(shell docker image inspect ranchertest/etcd:$(TAG) | jq -r \'.[] | .RepoDigests[0]\')
