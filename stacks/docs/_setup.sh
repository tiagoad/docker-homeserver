#!/bin/bash

set -x

mkdir -p "${SSD}/docs_heimdall"
chown ${PUID}:${PGID} "${SSD}/docs_heimdall"
