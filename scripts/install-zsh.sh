#!/bin/bash
set -eu
if [ ! -x /usr/bin/zsh ]; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y zsh
fi
usermod --shell /usr/bin/zsh "{{.User}}"
