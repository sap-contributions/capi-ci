#!/bin/bash

set -eu -o pipefail

: "${BBL_STATE_DIR:?}"
: "${DNS_DOMAIN:?}"
: "${SHARED_DNS_ZONE_NAME:?}"
: "${GCP_DNS_SERVICE_ACCOUNT_KEY:?}"
: "${GCP_PROJECT_ID:?}"

tmp_dir="$(mktemp -d /tmp/create-dns-record.XXXXXXXX)"
trap '{ rm -rf "${tmp_dir}"; }' EXIT

create_dns_record() {
  service_key_path="${tmp_dir}/gcp.json"
  echo "${GCP_DNS_SERVICE_ACCOUNT_KEY}" > "${service_key_path}"
  gcloud auth activate-service-account --key-file="${service_key_path}"
  gcloud config set project "${GCP_PROJECT_ID}"

  # GCP
  if bbl lbs --json | jq -e '.cf_system_domain_dns_servers' > /dev/null; then
    bbl_name_servers_json="$( bbl lbs --json | jq -r '.cf_system_domain_dns_servers' )"
    bbl_name_servers_raw="$( echo "${bbl_name_servers_json}" | jq -r 'join(" ")' )"
  # AWS
  elif bbl lbs --json | jq -e '.env_dns_zone_name_servers' > /dev/null; then
    bbl_name_servers_json="$( bbl lbs --json | jq -r '.env_dns_zone_name_servers | map(. + ".")' )"
    bbl_name_servers_raw="$( echo "${bbl_name_servers_json}" | jq -r 'join(" ")' )"
  # Azure does not return the DNS servers via `bbl lbs`, so we use `bbl outputs` instead
  else
    bbl_name_servers_raw="$( bbl outputs | yq -r '.system_domain_dns_servers | join(" ")' )"
  fi
  gcp_name_servers_json="$( gcloud dns record-sets list --zone "${SHARED_DNS_ZONE_NAME}" --name "${DNS_DOMAIN}" --format=json )"
  gcloud dns record-sets transaction start --zone="${SHARED_DNS_ZONE_NAME}"

  record_count="$( echo "${gcp_name_servers_json}" | jq 'length' )"
  if [ "${record_count}" != "0" ]; then
    gcp_name_servers_raw="$( echo "${gcp_name_servers_json}" | jq -r '.[0].rrdatas | join(" ")' )"
    gcloud dns record-sets transaction remove --name "${DNS_DOMAIN}" --type=NS --zone="${SHARED_DNS_ZONE_NAME}" --ttl=300 ${gcp_name_servers_raw} --verbosity=debug
  fi

  gcloud dns record-sets transaction add --name "${DNS_DOMAIN}" --type=NS --zone="${SHARED_DNS_ZONE_NAME}" --ttl=300 ${bbl_name_servers_raw} --verbosity=debug

  echo "Contents of transaction.yaml:"
  cat transaction.yaml
  gcloud dns record-sets transaction execute --zone="${SHARED_DNS_ZONE_NAME}" --verbosity=debug
}

pushd "bbl-state/${BBL_STATE_DIR}" > /dev/null
  create_dns_record
popd > /dev/null
