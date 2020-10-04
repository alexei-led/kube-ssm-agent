FROM amazonlinux:2

ARG SSM_VERSION

RUN printenv

# install systemd, sudo (needed to create ssm-user) and amazon-ssm-agent
RUN yum update -y && \
    yum install -y systemd sudo procps awscli jq && \
    amazon-linux-extras install docker vim -y && \
    yum install -y https://s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/${SSM_VERSION}/${TARGETOS}_${TARGETARCH}/amazon-ssm-agent.rpm && \
    yum clean all && \
    rm -rf /var/cache/yum

COPY sts-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/sts-entrypoint.sh

WORKDIR /opt/amazon/ssm/

ENTRYPOINT ["sts-entrypoint.sh"]
CMD ["amazon-ssm-agent", "start"]
