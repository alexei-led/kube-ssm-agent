[![](https://github.com/alexei-led/kube-ssm-agent/workflows/Docker%20Image%20CI/badge.svg)](https://github.com/alexei-led/kube-ssm-agent/actions?query=workflow%3A"Docker+Image+CI") [![](https://github.com/alexei-led/kube-ssm-agent/workflows/Check%20SSM%20Release/badge.svg)](https://github.com/alexei-led/kube-ssm-agent/actions?query=workflow%3A"Check+SSM+Release") [![Docker Pulls](https://img.shields.io/docker/pulls/alexeiled/aws-ssm-agent.svg?style=popout)](https://hub.docker.com/r/alexeiled/aws-ssm-agent) [![](https://images.microbadger.com/badges/image/alexeiled/aws-ssm-agent.svg)](https://microbadger.com/images/alexeiled/aws-ssm-agent "Get your own image badge on microbadger.com")

# kube-ssm-agent

The `kube-ssm-agent` is a _DeamonSet_ with [Amazon EC2 Simple Systems Manager (SSM) Agent](https://github.com/aws/amazon-ssm-agent) on-board to  specified Kubernetes nodes.

## Continuously Updated with GitHub Actions

The `kube-ssm-agent` is automatically updated when a new version of [Amazon SSM Agent](https://github.com/aws/amazon-ssm-agent) is released.

A GitHub Actions [Check SSM Release](https://github.com/alexei-led/kube-ssm-agent/actions?query=workflow%3A"Check+SSM+Release) workflow checks for a new version of Amazon SSM Agent, once a day, and triggers a new [Docker Image CI](https://github.com/alexei-led/kube-ssm-agent/actions?query=workflow%3A"Docker+Image+CI) workflow, if a new version is available.

## Pre-request

### Option 1

Create a new Kubernetes service account (`ssm-sa` for example) and connect it to IAM role with the `AmazonEC2RoleforSSM` policy attached.

```sh
$ export CLUSTER_NAME=gaia-kube
$ export SA_NAME=ssm-sa
$ export REGION=us-west-2

# setup IAM OIDC provider for EKS cluster
$ eksctl utils associate-iam-oidc-provider --region=$REGION --cluster=$CLUSTER_NAME --approve

# create K8s service account linked to IAM role in kube-system namespace
$ eksctl create iamserviceaccount --name $SA_NAME --cluster $CLUSTER_NAME --namespace kube-system \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM \
  --override-existing-serviceaccounts \
  --approve

[ℹ]  using region us-west-2
[ℹ]  1 iamserviceaccount (kube-system/ssm-sa) was included (based on the include/exclude rules)
[!]  serviceaccounts that exists in Kubernetes will be excluded, use --override-existing-serviceaccounts to override
[ℹ]  1 task: { 2 sequential sub-tasks: { create IAM role for serviceaccount "kube-system/ssm-sa", create serviceaccount "kube-system/ssm-sa" } }
[ℹ]  building iamserviceaccount stack "eksctl-gaia-kube-addon-iamserviceaccount-kube-system-ssm-sa"
[ℹ]  deploying stack "eksctl-gaia-kube-addon-iamserviceaccount-kube-system-ssm-sa"
[ℹ]  created serviceaccount "kube-system/ssm-sa"
```

Configure the SSM daemonset to use this service account.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ssm-agent
  labels:
    k8s-app: ssm-agent
  namespace: kube-syste
spec:
  ...
  template:
    ...
    spec:
      serviceAccountName: ssm-sa
      containers:
      - image: alexeiled/aws-ssm-agent
        name: ssm-agent
        ...
```

### Option 2 (less secure)

Assign `AmazonEC2RoleforSSM` policy to EC2 instance profile.

## Getting started

Clone this repository and run:

```console
$ kubectl apply -f daemonset.yaml

$ AWS_DEFAULT_REGION=$REGION aws ssm start-session --target <instance-id>

starting session with SessionId: ...

sh-4.2$ ls
sh-4.2$ pwd
/opt/amazon/ssm
sh-4.2$ bash -i
[ssm-user@ip-192-168-84-111 ssm]$

[ssm-user@ip-192-168-84-111 ssm]$ exit
sh-4.2$ exit

Exiting session with sessionId: ...
```

It worth noting that you should delete the `daemonset` when you don't need node access, so that a malicious user without K8S API access but with SSM sessions manager access
is unable to obtain root access to nodes.

## Rationale

This is an alternative to installing `aws-ssm-agent` binaries directly on nodes, or enabling `ssh` access on nodes.

This approach allows you to run an updated version SSM Agent without a need to install it into a host machine.

`aws-ssm-agent` with AWS SSM Sessions Manager allows you running commands and opening audited interactive terminal sessions to nodes, without maintaining SSH infrastructure.

## Troubleshooting

Q1. start-session fails like this

```console
$ aws ssm start-session --target i-04ffadbaae98a5bd0

An error occurred (TargetNotConnected) when calling the StartSession operation: i-04ffadbaae98a5bd0 is not connected.

SessionManagerPlugin is not found. Please refer to SessionManager Documentation here: http://docs.aws.amazon.com/console/systems-manager/session-manager-plugin-not-found
```

Q2. start session fails with "failed to create websocket for datachannel with error: CreateDataChannel" error

```console
----------ERROR-------
Setting up data channel with id alexei-0f1f1d0f80f2432b8 failed: failed to create websocket for datachannel with error: CreateDataChannel failed with no output or error: createDataChannel request failed: unexpected response from the service <BadRequest xmlns=""><message>Unauthorized request.</message></BadRequest>

```

This can be resolved by adding 'ssmmessages:CreateDataChannel' (Allow '*') to `NodeInstanceRole`. Probably a SSM bug.