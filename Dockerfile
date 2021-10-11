FROM amazonlinux:2 as builder

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG SSM_VERSION

RUN yum update -y && \
    yum install -y rpmdevtools rpm-build git golang make && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN mkdir -p /root/go/src
WORKDIR /root/go/src

RUN mkdir -p github.com/aws && \
    cd github.com/aws && \
    git clone https://github.com/aws/amazon-ssm-agent.git && \
    cd amazon-ssm-agent && \
    git checkout tags/${SSM_VERSION} && \
    echo ${SSM_VERSION} > VERSION

WORKDIR /root/go/src/github.com/aws/amazon-ssm-agent

RUN go get golang.org/x/tools/cmd/goimports && \
    export PATH=$PATH:/root/go/bin && \
    gofmt -w agent/plugins/inventory/gatherers/application/dataProvider_unix_test.go && \
    goimports -w agent/plugins/inventory/gatherers/application/dataProvider.go

RUN if [ "amd64" == "${TARGETARCH}" ]; then go mod vendor; make build-linux package-rpm; fi
RUN if [ "arm64" == "${TARGETARCH}" ]; then go mod vendor; make build-arm64 package-rpm-arm64; fi

# Release image

FROM amazonlinux:2

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG SSM_VERSION

# install systemd, sudo (needed to create ssm-user)
RUN yum update -y && \
    yum install -y systemd sudo procps awscli jq which && \
    amazon-linux-extras install docker vim -y && \
    yum clean all && \
    rm -rf /var/cache/yum

# copy amazon-ssm-agent RPM from builder and install it
COPY --from=builder /root/go/src/github.com/aws/amazon-ssm-agent/bin/${TARGETOS}_${TARGETARCH}/amazon-ssm-agent.rpm /root/
RUN yum install -y /root/amazon-ssm-agent.rpm && \
    yum clean all && \
    rm -rf /var/cache/yum

COPY sts-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/sts-entrypoint.sh

WORKDIR /opt/amazon/ssm/

ENTRYPOINT ["sts-entrypoint.sh"]
CMD ["amazon-ssm-agent", "start"]
