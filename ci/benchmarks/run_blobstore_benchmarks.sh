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

perform_blobstore_benchmarks() {
  echo "Performing blobstore benchmarks via errands..."
  # Run serially to avoid interference
  run_errand "${ERRAND_STORAGE_CLI}"
  run_errand "${ERRAND_FOG}"
}

main() {
  setup_bbl_environment
  perform_blobstore_benchmarks
}

main
