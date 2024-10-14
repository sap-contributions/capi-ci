#!/usr/bin/env bash

set -e

BOSH_ENV=""
CA_CERTIFICATES=()

function setup_environment() {
  echo "Setting up bbl env ..."
  pushd "bbl-state/${BBL_STATE_DIR}" > /dev/null
    eval "$(bbl print-env)"
  popd > /dev/null

  BOSH_ENV="$(bosh environment --json | jq -r .Tables[0].Rows[0].name)"
  echo "BOSH environment is $BOSH_ENV"

  IFS=, read -r -a CA_CERTIFICATES <<< "$CA_CERTS"
}

function rotate_step_1() {
  echo "Rotating CA certificates - step 1 ..."

  for ca_cert in "${CA_CERTIFICATES[@]}"
  do
    echo "Generating new transitional version for $ca_cert ..."
    ca_cert_guid="$(credhub curl -p "/api/v1/certificates?name=/$BOSH_ENV/cf/$ca_cert" | jq -r .certificates[0].id)"
    # if certificate is already marked as transitional, the command will throw an error message but exit with 0
    curl -p "/api/v1/certificates/$ca_cert_guid/regenerate" -d '{"set_as_transitional": true}' -X POST
  done
}

function rotate_step_2() {
  echo "Rotating CA certificates - step 2 ..."

  for ca_cert in "${CA_CERTIFICATES[@]}"
  do
    echo "Moving transitional flag for $ca_cert ..."
    ca_cert_guid="$(credhub curl -p "/api/v1/certificates?name=/$BOSH_ENV/cf/$ca_cert" | jq -r .certificates[0].id)"
    ca_cert_non_transitional_version="$(credhub curl -p "/api/v1/certificates?name=/$BOSH_ENV/cf/$ca_cert" | jq -r '.certificates[0].versions[] | select(.transitional==false) | .id')"
    credhub curl -p "/api/v1/certificates/$ca_cert_guid/update_transitional_version" -d "{\"version\": \"$ca_cert_non_transitional_version\"}" -X PUT

    echo "Regenerating signed certificates ..."
    credhub curl -p "/api/v1/bulk-regenerate" -d "{\"signed_by\": \"/$BOSH_ENV/cf/$ca_cert\"}" -X POST
  done
}

function rotate_step_3() {
  echo "Rotating CA certificates - step 3 ..."

  for ca_cert in "${CA_CERTIFICATES[@]}"
  do
    echo "Removing transitional flag for $ca_cert ..."
    ca_cert_guid="$(credhub curl -p "/api/v1/certificates?name=/$BOSH_ENV/cf/$ca_cert" | jq -r .certificates[0].id)"
    credhub curl -p "/api/v1/certificates/$ca_cert_guid/update_transitional_version" -d '{"version": null}' -X PUT
  done
}

function main() {
  setup_bosh_env_vars
  rotate_"$STEP"
  echo "Done"
}

main