#!/usr/bin/env bash
set -e

docker build -f Dockerfile . --tag swiftsh-test-server
ssh-keygen -R [127.0.0.1]:2222
docker run --rm --publish 2222:22 --name swiftsh-test-server swiftsh-test-server
