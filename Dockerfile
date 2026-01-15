ARG GO_IMAGE=rancher/hardened-build-base:v1.24.12b1

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.6.1 AS xx

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base-builder
# copy xx scripts to your build stage
COPY --from=xx / /
RUN apk add file make git clang lld
ARG TARGETPLATFORM
# setup required packages
RUN set -x && \
    xx-info env &&\
    xx-apk --no-cache add musl-dev gcc \
    libselinux-dev \
    libseccomp-dev 

FROM base-builder AS etcd-builder
# setup the build
ARG TARGETARCH
ARG PKG=go.etcd.io/etcd
ARG SRC=github.com/k3s-io/etcd
ARG TAG=v3.6.6-k3s1
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN go mod vendor
RUN go mod download
# cross-compilation setup
ARG TARGETPLATFORM
# build and assert statically linked executable(s)
RUN xx-go --wrap && \
    export GO_LDFLAGS="-linkmode=external -X ${PKG}/version.GitSHA=$(git rev-parse --short HEAD)" && \
    if echo ${TAG} | grep -qE '^v3\.4\.'; then \
        go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/etcd . && \
        go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/etcdctl ./etcdctl; \
    else \
        cd $GOPATH/src/${PKG}/server  && go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o ../bin/etcd . && \
        cd $GOPATH/src/${PKG}/etcdctl && go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o ../bin/etcdctl .; \
    fi

RUN xx-verify --static bin/*
RUN go-assert-static.sh bin/*
ARG ETCD_UNSUPPORTED_ARCH
ENV ETCD_UNSUPPORTED_ARCH=$ETCD_UNSUPPORTED_ARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
	    go-assert-boring.sh bin/*; \
    fi
RUN install bin/* /usr/local/bin

FROM ${GO_IMAGE} AS strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=etcd-builder /usr/local/bin/ /usr/local/bin
RUN for bin in $(ls /usr/local/bin); do \
        strip /usr/local/bin/${bin}; \
    done
RUN etcd --version

FROM scratch
ARG ETCD_UNSUPPORTED_ARCH
LABEL org.opencontainers.image.source="https://github.com/rancher/image-build-etcd"
ENV ETCD_UNSUPPORTED_ARCH=$ETCD_UNSUPPORTED_ARCH
COPY --from=strip_binary /usr/local/bin/ /usr/local/bin/
