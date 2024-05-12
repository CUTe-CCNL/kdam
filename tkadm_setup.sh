#!/bin/bash

source ./variable.sh
[ -d ~/$talosName ] && rm -r $HOME/$talosName &>/dev/null
mkdir -p $HOME/$talosName
[ $? == 0 ] && echo "mkdir $talosName ok"

echo "Talos Version : $tkver"

# Install talosctl
version_output=$(talosctl version 2>/dev/null | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*')

if [ "$version_output" != v$tkver ] || [ -z "$version_output" ]; then
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
mv ./output/* $HOME/$talosName && rm -r ./output && cp -r ./talos $HOME/$talosName
[ $? == 0 ] && echo "mv talos ok"