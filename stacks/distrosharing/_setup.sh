#!/bin/bash

set -x

# torrents

mkdir -p "${RAID_ROOT}/downloads/oc"
chown 1000:1000 "${RAID_ROOT}/downloads/oc"

mkdir -p "${NORAID_ROOT}/downloads/archive1"
chown 1000:1000 "${NORAID_ROOT}/downloads/archive1"

mkdir -p "${RAID}/transmission/oc/"
mkdir -p "${RAID}/transmission/archive1"
chown -R 1000:1000 "${RAID}/transmission/"

# usenet
mkdir -p "${NORAID_ROOT}/downloads/sabnzbd"
chown -R 1000:1000 "${NORAID_ROOT}/downloads/sabnzbd"
mkdir -p "${RAID}/usenet/sabnzbd"
mkdir -p "${RAID}/usenet/hydra2"
mkdir -p "${RAID}/usenet/sonarr"
mkdir -p "${RAID}/usenet/radarr"
mkdir -p "${RAID}/usenet/bazarr"

chown -R 1000:1000 "${RAID}/usenet/"
