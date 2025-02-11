#!/usr/bin/env bash
set -e
set -x

if [[ $# -ne 2 ]]; then
    echo "Please provide the source and destination paths for configuration"
    exit -1
fi
SRC_PATH=$1
DST_PATH=$2

export GH_USERNAME="jenkins-x-dev"
export GH_EMAIL="rbizzell@burwood.com"
export GH_OWNER="cb-kubecd"

export GH_CREDS_PSW="$(jx step credential -s jenkins-x-dev-github)"
export JENKINS_CREDS_PSW="$(jx step credential -s  dev-jenkins-user)"
export GKE_SA="$(jx step credential -k bdd-credentials.json -s bdd-secret -f sa.json)"

# fix broken `BUILD_NUMBER` env var
export BUILD_NUMBER="$BUILD_ID"

JX_HOME="/tmp/jxhome"
KUBECONFIG="/tmp/jxhome/config"

mkdir -p $JX_HOME

jx --version
jx step git credentials

gcloud auth activate-service-account --key-file $GKE_SA

# lets setup git 
git config --global --add user.name JenkinsXBot
git config --global --add user.email rbizzell@burwood.com

echo "running the BDD tests with JX_HOME = $JX_HOME"

# setup jx boot parameters
export JX_VALUE_ADMINUSER_PASSWORD="$JENKINS_CREDS_PSW"
export JX_VALUE_PIPELINEUSER_USERNAME="$GH_USERNAME"
export JX_VALUE_PIPELINEUSER_EMAIL="$GH_EMAIL"
export JX_VALUE_PIPELINEUSER_TOKEN="$GH_CREDS_PSW"
export JX_VALUE_PROW_HMACTOKEN="$GH_CREDS_PSW"

# TODO temporary hack until the batch mode in jx is fixed...
export JX_BATCH_MODE="true"

# prepare the BDD configuration
mkdir -p $DST_PATH
cp -r `ls -A | grep -v "${DST_PATH}"` $DST_PATH
cp $SRC_PATH/jx-requirements.yml $DST_PATH
cp $SRC_PATH/parameters.yaml $DST_PATH/env
cd $DST_PATH

# TODO hack until we fix boot to do this too!
helm init --client-only
helm repo add jenkins-x https://storage.googleapis.com/chartmuseum.jenkins-x.io

jx step bdd \
    --use-revision \
    --versions-repo https://github.com/jenkins-x/jenkins-x-versions.git \
    --config $SRC_PATH/cluster.yaml \
    --gopath /tmp \
    --git-provider=github \
    --git-username $GH_USERNAME \
    --git-owner $GH_OWNER \
    --git-api-token $GH_CREDS_PSW \
    --default-admin-password $JENKINS_CREDS_PSW \
    --no-delete-app \
    --no-delete-repo \
    --tests install \
    --tests test-create-spring
