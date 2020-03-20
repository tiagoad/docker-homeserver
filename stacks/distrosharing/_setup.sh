#!/bin/bash

set -x

mkdir -p "${SSD}/ds_bazarr"
mkdir -p "${SSD}/ds_hydra2"
mkdir -p "${SSD}/ds_radarr"
mkdir -p "${SSD}/ds_sabnzbd"
mkdir -p "${SSD}/ds_sonarr"
mkdir -p "${SSD}/ds_transmission-archive"
mkdir -p "${SSD}/ds_transmission-oc"

mkdir -p "${HDD}/ds_transmission-archive"
mkdir -p "${HDD}/ds_transmission-oc"
mkdir -p "${HDD}/ds_sabnzbd"

chown ${PUID}:${PGID} "${SSD}/ds_"*
chown ${PUID}:${PGID} "${HDD}/ds_"*
