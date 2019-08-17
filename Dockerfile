FROM amazonlinux:2

# install systemd, sudo (needed to create ssm-user) and amazon-ssm-agent
RUN yum update -y && \
    yum install -y systemd sudo procps awscli && \
    amazon-linux-extras install docker vim -y && \
    yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/2.3.687.0/linux_amd64/amazon-ssm-agent.rpm && \
    yum clean all && \
    rm -rf /var/cache/yum

WORKDIR /opt/amazon/ssm/
ENTRYPOINT ["amazon-ssm-agent", "start"]
