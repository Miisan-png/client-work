#!/bin/sh
echo -ne '\033c\033]0;SF\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/SF.x86_64" "$@"
