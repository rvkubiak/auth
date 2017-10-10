#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -x

function usage() {
  echo "$0 \
    -b <GCS bucket for release artifacts> \
    -h <comma delimited list of docker repositories> \
    -t <tag name to apply to artifacts> \
    -v <version to apply instead of tag>"
  exit 1
}

# Initialize variables
BUCKET="istio-release"
HUBS="gcr.io/istio-io,docker.io/istio"
TAG_NAME=""
VERSION_OVERRIDE=""

# Handle command line args
while getopts b:h:t:v: arg ; do
  case "${arg}" in
    b) BUCKET="${OPTARG}";;
    h) HUBS="${OPTARG}";;
    t) TAG_NAME="${OPTARG}";;
    v) VERSION_OVERRIDE="${OPTARG}";;
    *) usage;;
  esac
done

if [ ! -z "${VERSION_OVERRIDE}" ] ; then
  version="${VERSION_OVERRIDE}"
elif [ ! -z "${TAG_NAME}" ] ; then
  version="${TAG_NAME}"
else
  echo "Either -t or -v is a required argument."
  usage
fi

if [[ "$HUBS" == *"docker.io"* ]] ; then
  mkdir -p $HOME/.docker
  gsutil cp gs://istio-secrets/dockerhub_config.json.enc $HOME/.docker/config.json.enc
  gcloud kms decrypt \
         --ciphertext-file=$HOME/.docker/config.json.enc \
         --plaintext-file=$HOME/.docker/config.json \
         --location=global \
         --keyring=Secrets \
         --key=DockerHub
fi

./bin/push-docker.sh \
    -h "${HUBS}" \
    -t "${version}"

./bin/push-debian.sh \
    -c opt \
    -v "${version}" \
    -p "gs://${BUCKET}/releases/${version}/deb"
