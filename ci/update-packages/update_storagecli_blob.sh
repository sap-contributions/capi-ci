#!/bin/bash

set -eu -o pipefail

if [[ -z "${PRIVATE_YAML}" ]]; then
  echo "Error: PRIVATE_YAML is not set."
  exit 1
fi

echo "${PRIVATE_YAML}" > "${PWD}/capi-release/config/private.yml"

pushd capi-release > /dev/null
  current_storagecli_blob_name=$(grep -m 1 "storage-cli" config/blobs.yml | awk -F':' '{print $1}') || { echo "Error: grep command failed."; exit 1; }
  current_storagecli_version=$(echo "${current_storagecli_blob_name}" | awk -F'/' '{print $2}' | awk -F'storage-cli-' '{print $2}' | awk -F'-linux-amd64' '{print $1}') || { echo "Error: awk command failed."; exit 1; }

  if [ -z "$current_storagecli_blob_name" ] || [ -z "$current_storagecli_version" ]; then
    echo "Either no storage-cli entry found or no version found for storage-cli in blobs.yml."
    exit 1
  fi

  echo "Current storage-cli version is '${current_storagecli_version}'"
popd > /dev/null

pushd storage-cli-release > /dev/null
  new_storagecli_version=$(cat version | sed 's/^v//') || { echo "Error: cat command for version failed."; exit 1; }
  new_storagecli_binary="${PWD}/storage-cli-${new_storagecli_version}-linux-amd64"
  new_storagecli_url=$(cat url) || { echo "Error: cat command for url failed."; exit 1; }
  
  if [ ! -f "$new_storagecli_binary" ]; then
    echo "Error: Binary file ${new_storagecli_binary} not found."
    exit 1
  fi
  
  pushd capi-release > /dev/null
    bosh remove-blob -n "${current_storagecli_blob_name}"
    bosh add-blob -n "$new_storagecli_binary" storage-cli/storage-cli-"${new_storagecli_version}"-linux-amd64
if [[ "$current_storagecli_version" == "$new_storagecli_version" ]]; then
  echo "The current storage-cli version is the same as the new version."
else
  pushd capi-release > /dev/null
    bosh remove-blob -n "${current_storagecli_blob_name}"
    bosh add-blob -n "$new_storagecli_source_tgz" storage-cli/"${new_storagecli_version}".tar.gz

    sed -i "0,/$current_storagecli_version/s//$new_storagecli_version/" packages/storage-cli/packaging || { echo "Error: sed command for 'packaging' failed."; exit 1; }
    sed -i "s/$current_storagecli_version/$new_storagecli_version/g" packages/storage-cli/README.md || { echo "Error: sed command for 'README' failed."; exit 1; }
    sed -i "0,/$current_storagecli_version/s//$new_storagecli_version/" packages/storage-cli/spec || { echo "Error: sed command for 'spec' failed."; exit 1; }

    bosh upload-blobs -n

    git --no-pager diff packages .final_builds config

    git config user.name "ari-wg-gitbot"
    git config user.email "app-runtime-interfaces@cloudfoundry.org"

    git add -A packages .final_builds config
    git commit -m "Bump storage-cli to $new_storagecli_version" -m "Changes: $new_storagecli_url"  || { echo "Error: git commit failed."; exit 1; }
  popd > /dev/null
fi

cp -r capi-release/. updated-capi-release
