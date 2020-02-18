#!/bin/bash

# create swarm networks
docker network create -d overlay --internal http || true
docker network create -d overlay internet || true