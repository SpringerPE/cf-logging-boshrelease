#!/usr/bin/env bash
set -o pipefail  # exit if pipe command fails
[ -z "$DEBUG" ] || set -x

BOSH_CLI=${BOSH_CLI:-bosh}


$BOSH_CLI int logstash.yml \
    -o operations/pipelines/cf-platform-es.yml \
    -o operations/add-es-cloud-id.yml \
    -o operations/add-es-xpack.yml \
    -o operations/add-release-version.yml  --vars-file vars-release-version.yml \
    -o operations/add-iaas-parameters.yml  --vars-file vars-iaas-parameters.yml \
    # --vars-store secrets-example.yml
