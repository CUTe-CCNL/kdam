#!/bin/bash

[ -d ~/iso ] && sudo rm -r ~/iso && sudo mkdir ~/iso &>/dev/null

source ./variable.sh


echo "Talos Version : $tkver"

# Remaster Talos ISO

for s in $isolist; do
	vn=$(echo $s | cut -d ':' -f 1)
	ip=$(echo $s | cut -d ':' -f 2)

	sudo podman run --rm -v .:/tmp --entrypoint bash "ghcr.io/siderolabs/imager:v${tkver}" \
		-c "imager iso --arch amd64 --extra-kernel-arg 'net.ifnames=0 \
  ip=$netid.$ip::$netid.254:255.255.255.0:$vn:eth0:off:8.8.8.8:168.95.1.1:' --output /tmp" &>/dev/null

	sudo mv ./metal-amd64.iso ~/iso/tk8s-$vn-$netid.$ip.iso
	[ "$?" == "0" ] && echo "tk8s-$vn-$netid.$ip.iso ok"
done
