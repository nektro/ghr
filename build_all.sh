#!/usr/bin/env bash

set -e

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
