#!/usr/bin/env bash

set -e

tagcount=$(git tag | wc -l)
tagcount=$((tagcount+1))

version="v$tagcount"

GITHUB_TOKEN="$1"
PROJECT_USERNAME=$(echo $GITHUB_REPOSITORY | cut -d'/' -f1)
PROJECT_REPONAME=$(echo $GITHUB_REPOSITORY | cut -d'/' -f2)

./zig-out/bin/ghr-linux-x86_64 \
    -t "$GITHUB_TOKEN" \
    -u "$PROJECT_USERNAME" \
    -r "$PROJECT_REPONAME" \
    -b "$(./changelog.sh)" \
    "$version" \
    "./zig-out/bin/"
