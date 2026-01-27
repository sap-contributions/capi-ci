#!/bin/bash
set -eu

: "${BOSH_DEPLOYMENT_NAME:="cf"}"
: "${ERRAND_STORAGE_CLI:="blobstore-benchmark-storage-cli"}"
: "${ERRAND_FOG:="blobstore-benchmark-fog"}"

setup_bbl_environment() {
  pushd "capi-ci-private/${BBL_STATE_DIR}" > /dev/null
    eval "$(bbl print-env)"
  popd > /dev/null
}

run_errand() {
  local errand="$1"
  echo ""
  echo "===== Running errand: ${errand} (deployment: ${BOSH_DEPLOYMENT_NAME}) ====="
  bosh -d "${BOSH_DEPLOYMENT_NAME}" run-errand "${errand}"
}

# Skip storage-cli benchmarks if SKIP_STORAGE_CLI is set to true, can be reverted once s3 is configured in storage-cli
: "${SKIP_STORAGE_CLI:=false}"

perform_blobstore_benchmarks() {
  echo "Performing blobstore benchmarks via errands..."
  if [ "${SKIP_STORAGE_CLI}" != "true" ]; then
    run_errand "${ERRAND_STORAGE_CLI}"
  else
    echo "Skipping storage-cli errand"
  fi
  run_errand "${ERRAND_FOG}"
}

main() {
  setup_bbl_environment
  perform_blobstore_benchmarks
}

main
