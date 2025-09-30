#!/bin/bash

set -eu

function main() {
  shopt -s dotglob
  cp -R "capi-ci-private-certs/." "updated-capi-ci-private-certs/"

  pushd "updated-capi-ci-private-certs" > /dev/null
    echo "Exporting ${BBL_ENV_NAME} certificate from CredHub to PKCS12 format ..."
    echo "${BBL_LB_CERT}" > /tmp/bbl-cert
    echo "${BBL_LB_KEY}" > /tmp/bbl-key
    openssl pkcs12 -export -out "${BBL_ENV_NAME}/${BBL_ENV_NAME}.pfx" \
     -inkey "/tmp/bbl-key" -in "/tmp/bbl-cert" -passout "file:${BBL_ENV_NAME}/pfx_password.txt" -legacy
    echo "Export finished."

    status="$(git status --porcelain)"
    if [[ -n "$status" ]]; then
      echo "Committing changed certificate to git..."
      git config user.name "${GIT_COMMIT_USERNAME}"
      git config user.email "${GIT_COMMIT_EMAIL}"
      git add "${BBL_ENV_NAME}/${BBL_ENV_NAME}.pfx"
      git commit -m "Update ${BBL_ENV_NAME}.pfx certificate"
    fi
  popd > /dev/null
}

main
