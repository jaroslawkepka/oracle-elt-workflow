#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ORACLE_CONTAINER_NAME="${ORACLE_CONTAINER_NAME:-oracle-elt-workflow}"
ORACLE_VOLUME_NAME="${ORACLE_VOLUME_NAME:-oracle-elt-workflow-data}"
ORACLE_IMAGE="${ORACLE_IMAGE:-docker.io/gvenzl/oracle-free@sha256:62aad247879f5d4ca4a37ecc068ef6a5feb9e9bea789501b6a82d4814d14bbb3}"
ORACLE_PASSWORD="${ORACLE_PASSWORD:-}"
ORACLE_TZ="${ORACLE_TZ:-Europe/Berlin}"

if [[ "$(podman info --format '{{.Host.Security.Rootless}}')" != "true" ]]; then
  echo "Run this helper with rootless Podman." >&2
  exit 1
fi

if podman container inspect "${ORACLE_CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "Container ${ORACLE_CONTAINER_NAME} already exists." >&2
  echo "To start it, run: podman start ${ORACLE_CONTAINER_NAME}" >&2
  exit 1
fi

if [[ -z "${ORACLE_PASSWORD}" ]]; then
  if [[ -t 0 ]]; then
    read -r -s -p "Enter ORACLE_PASSWORD: " ORACLE_PASSWORD
    echo
  else
    echo "Set ORACLE_PASSWORD before starting the container in non-interactive mode." >&2
    exit 1
  fi
fi

if [[ -z "${ORACLE_PASSWORD}" ]]; then
  echo "ORACLE_PASSWORD cannot be empty." >&2
  exit 1
fi

mkdir -p "${REPO_ROOT}/extdata/inbound" "${REPO_ROOT}/extdata/outbound" "${REPO_ROOT}/extdata/work"

podman volume create --ignore "${ORACLE_VOLUME_NAME}" >/dev/null

# Map the host user to oracle (54321:54321) in the pinned image.
podman run -d --name "${ORACLE_CONTAINER_NAME}" \
  --userns=keep-id:uid=54321,gid=54321 \
  --user oracle \
  -p 127.0.0.1:1521:1521 \
  -p 127.0.0.1:5500:5500 \
  -e ORACLE_PASSWORD="${ORACLE_PASSWORD}" \
  -e TZ="${ORACLE_TZ}" \
  -e ORA_SDTZ="${ORACLE_TZ}" \
  -v "${ORACLE_VOLUME_NAME}:/opt/oracle/oradata" \
  -v "${REPO_ROOT}/extdata/inbound:/opt/oracle/extdata/inbound:ro,Z" \
  -v "${REPO_ROOT}/extdata/outbound:/opt/oracle/extdata/outbound:rw,Z" \
  -v "${REPO_ROOT}/extdata/work:/opt/oracle/extdata/work:rw,Z" \
  -v "${REPO_ROOT}:/workspace:ro,Z" \
  "${ORACLE_IMAGE}"

echo "Started ${ORACLE_CONTAINER_NAME} with timezone ${ORACLE_TZ}."
echo "Current startup config uses TZ=${ORACLE_TZ} and ORA_SDTZ=${ORACLE_TZ}."
