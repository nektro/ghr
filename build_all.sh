#!/usr/bin/env bash

set -e

tagcount=$(git tag | wc -l)
tagcount=$((tagcount+1))

targets="
x86_64-linux
x86_64-macos
x86_64-windows
"

for item in $targets
do
    echo "$item"
    zig build -Dtarget=$item
done
