#!/usr/bin/env bash

set -e

tagcount=$(git tag | wc -l)
tagcount=$((tagcount+1))

targets="
x86_64-linux-musl
x86_64-macos
x86_64-windows-gnu
aarch64-linux-musl
aarch64-macos
aarch64-windows-gnu
"

for item in $targets
do
    echo "$item"
    zig build -Dtarget="$item" -Dfull-name
done
