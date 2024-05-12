#!/bin/bash
source ./variable.sh

if ([ "$1" == "" ] || ([ "$1" != "install" ]) ); then
   echo "talos_setup.sh <type>"
   echo -e "\ntype:"
   echo "  install -> install talos-k8s"
   echo
   exit 1
fi

# Check Talos Nodes
for s in $isolist; do
    ip=$netid.$(echo $s | cut -d ':' -f 2)
    talosctl -n $ip get addressspecs.net.talos.dev -i &>/dev/null

    if [ $? -ne 0 ]; then
        echo "Error encountered with $ip. Stopping"
         exit 1
    fi
done

echo "Talos Version : $tkver"

# Talos Control Plane Setup
talosctl apply-config --insecure --nodes $M1 --file $HOME/$talosName/talos/${k8sName}m1.yaml
[ "$?" == "0" ] && echo "Talos Control Plane ($M1) config"
echo "waiting 240" && sleep 240

talosctl -n $M1 dmesg 2>/dev/null | grep 'talosctl bootstrap' &>/dev/null
if [ "$?" != "0" ]; then
   echo "waiting 600"; sleep 600
   talosctl -n $M1 dmesg 2>/dev/null | grep 'talosctl bootstrap' &>/dev/null
   [ "$?" != "0" ] && echo "talosctl bootstrap error" && exit 1
fi

talosctl --nodes $M1 --talosconfig=$HOME/$talosName/talosconfig bootstrap
[ "$?" != "0" ] && echo "k1m1($M1) bootstrap failure" && exit 1
echo "${k8sName}m1($M1) bootstrap ok"
echo "waiting 300" && sleep 300

nc -w 1 $M1 6443
if [ "$?" != "0" ]; then
   echo "waiting 600" && sleep 600
   nc -w 1 $M1 6443
   [ "$?" != "0" ] && echo "${k8sName}m1 Control Plane failure" && exit 1
fi


# Talos Worker Node Setup
talosctl apply-config --insecure --nodes $W1 --file $HOME/$talosName/talos/${k8sName}w1.yaml
[ "$?" == "0" ] && echo "${k8sName}w1($W1) config"

talosctl apply-config --insecure --nodes $W2 --file $HOME/$talosName/talos/${k8sName}w2.yaml
[ "$?" == "0" ] && echo "${k8sName}w2($W2) config"

talosctl apply-config --insecure --nodes $W3 --file $HOME/$talosName/talos/${k8sName}w3.yaml
[ "$?" == "0" ] && echo "${k8sName}w3($W3) config"

talosctl apply-config --insecure --nodes $W4 --file $HOME/$talosName/talos/${k8sName}w4.yaml
[ "$?" == "0" ] && echo "${k8sName}w4($W4) config"

talosctl apply-config --insecure --nodes $W5 --file $HOME/$talosName/talos/${k8sName}w5.yaml
[ "$?" == "0" ] && echo "${k8sName}w2($W5) config"
echo "waiting 360" && sleep 360


# Tkadm Kubectl Setup
curl -LO https://dl.k8s.io/release/v$k8sver/bin/linux/amd64/kubectl &>/dev/null
sudo mv kubectl /usr/local/bin/ && sudo chmod 755 /usr/local/bin/kubectl
[ -d $HOME/.kube ] && rm -r $HOME/.kube && mkdir $HOME/.kube
talosctl --nodes $M1 --talosconfig=$HOME/$talosName/talosconfig kubeconfig


# node-role.kubernetes.io/master=k8sName
kubectl label node k1w1 node-role.kubernetes.io/worker=$k8sName &>/dev/null
kubectl label node k1w2 node-role.kubernetes.io/worker=$k8sName &>/dev/null
kubectl label node k1w3 node-role.kubernetes.io/worker=$k8sName &>/dev/null
kubectl label node k1w4 node-role.kubernetes.io/worker=$k8sName &>/dev/null
kubectl label node k1w5 node-role.kubernetes.io/worker=$k8sName &>/dev/null
echo ""


if [ "$1" == "install" ]; then
   exit 0
fi
