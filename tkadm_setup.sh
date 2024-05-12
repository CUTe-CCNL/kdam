#!/bin/bash

source ./variable.sh
[ -d ~/1m5w ] && rm -r ~/1m5w &>/dev/null
mkdir -p ~/1m5w
[ $? == 0 ] && echo "mkdir 1m5w ok"

echo "Talos Version : $tkver"

# Install talosctl
version_output=$(talosctl version 2>/dev/null | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*')

if [ "$version_output" != "v1.7.1" ] || [ -z "$version_output" ]; then
  sudo curl -Lo /usr/local/bin/talosctl "https://github.com/siderolabs/talos/releases/download/v$tkver/talosctl-linux-amd64" &>/dev/null
  [ $? == 0 ] && sudo chmod 755 /usr/local/bin/talosctl && echo "talosctl ok"
fi

mkdir -p ./output
talosctl gen secrets -o secrets.yaml
[ $? == 0 ] && echo "secrets.yaml ok"

talosctl gen config --with-secrets secrets.yaml $k8sName https://$apiserver:6443 &>/dev/null
[ $? == 0 ] && echo "config.yaml ok"
[ $? == 0 ] && echo "talosconfig ok"

mv secrets.yaml ./output && mv ./*.yaml ./output && mv ./talosconfig ./output
mv ./output/* ~/1m5w && rm -r ./output && cp -r ./talos ~/1m5w
[ $? == 0 ] && echo "mv talos ok"