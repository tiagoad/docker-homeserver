#!/bin/bash

set -x

mkdir -p "${SSD}/media_airsonic"
chown ${PUID}:${PGID} "${SSD}/media_airsonic"
