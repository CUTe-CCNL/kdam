#!/bin/bash

tv=1.6.7

if ([ "$1" == "" ] || ([ "$1" != "basic" ] && [ "$1" != "minio" ] && [ "$1" != "dt" ] && [ "$1" != "cicd" ]) ); then
   echo "1m2w.sh <type>"
   echo -e "\ntype:"
   echo "  basic -> kube-Kadm + Metric Server + MetalLB"
   echo "  Spark -> kube-Kadm + Metric Server + MetalLB + Spark"
   echo "  minio -> kube-Kadm + Metric Server + MetalLB + MinIO SNSD + DirectPV"
   echo "  dt -> kube-Kadm + Metric Server + MetalLB + MinIO MNMD + MySQL NDB + Spark"
   echo "  cicd -> kube-Kadm + Metric Server + MetalLB + Jenkins + Argo"
   echo
   exit 1
fi

M1="172.22.1.11"
W1="172.22.1.21"
W2="172.22.1.22"
W3="172.22.1.23"
W4="172.22.1.24"
W5="172.22.1.25"

clear
# Talos Control Plane Setup
talosctl apply-config --insecure --nodes $M1 --file /home/bigred/talos/k1m1.yaml
[ "$?" == "0" ] && echo "Talos Control Plane ($M1) config"
echo "waiting 240" && sleep 240

talosctl -n $M1 dmesg 2>/dev/null | grep 'talosctl bootstrap' &>/dev/null
if [ "$?" != "0" ]; then
   echo "waiting 600"; sleep 600
   talosctl -n $M1 dmesg 2>/dev/null | grep 'talosctl bootstrap' &>/dev/null
   [ "$?" != "0" ] && echo "talosctl bootstrap error" && exit 1
fi

talosctl --nodes $M1 --talosconfig=/home/bigred/talos/talosconfig bootstrap
[ "$?" != "0" ] && echo "k1m1($M1) bootstrap failure" && exit 1
echo "k1m1($M1) bootstrap ok"
echo "waiting 300" && sleep 300

nc -w 1 $M1 6443
if [ "$?" != "0" ]; then
   echo "waiting 600" && sleep 600
   nc -w 1 $M1 6443
   [ "$?" != "0" ] && echo "K1m1 Control Plane failure" && exit 1
fi

# Talos Worker Node Setup
talosctl apply-config --insecure --nodes $W1 --file /home/bigred/talos/k1w1.yaml
[ "$?" == "0" ] && echo "k1w1($W1) config"

talosctl apply-config --insecure --nodes $W2 --file /home/bigred/talos/k1w2.yaml
[ "$?" == "0" ] && echo "k1w2($W2) config"

talosctl apply-config --insecure --nodes $W3 --file /home/bigred/talos/k1w3.yaml
[ "$?" == "0" ] && echo "k1w3($W3) config"

talosctl apply-config --insecure --nodes $W4 --file /home/bigred/talos/k1w4.yaml
[ "$?" == "0" ] && echo "k1w4($W4) config"

talosctl apply-config --insecure --nodes $W5 --file /home/bigred/talos/k1w5.yaml
[ "$?" == "0" ] && echo "k1w2($W5) config"
echo "waiting 360" && sleep 360

# Tkadm Kubectl Setup
curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl &>/dev/null
sudo mv kubectl /usr/local/bin/ && sudo chmod 755 /usr/local/bin/kubectl
[ -d /home/bigred/.kube ] && rm -r /home/bigred/.kube && mkdir /home/bigred/.kube
talosctl --nodes $M1 --talosconfig=/home/bigred/talos/talosconfig kubeconfig

# node-role.kubernetes.io/master=k1
kubectl label node k1w1 node-role.kubernetes.io/worker=k1 &>/dev/null
kubectl label node k1w2 node-role.kubernetes.io/worker=k1 &>/dev/null
kubectl label node k1w3 node-role.kubernetes.io/worker=k1 &>/dev/null
kubectl label node k1w4 node-role.kubernetes.io/worker=k1 &>/dev/null
kubectl label node k1w5 node-role.kubernetes.io/worker=k1 &>/dev/null
echo ""

# container registry
kubectl apply -f ~/wulin/wkload/kadm/kube-kadm-dkreg.yaml &>/dev/null
sleep 90
kubectl get pods -n kube-system | grep 'kube-kadm' | grep '2/2' &>/dev/null
[ "$?" != "0" ] && echo "kube-kadm error" && exit 1
echo "kube-kadm ok"
echo

kubectl get secret 2>/dev/null | grep dkreg &>/dev/null
if [ "$?" != "0" ]; then
   sudo podman login --tls-verify=false -u bigred -p bigred 172.22.1.11:5000 &>/dev/null
   if [ "$?" != "0" ]; then
      sleep 60
      sudo podman login --tls-verify=false -u bigred -p bigred 172.22.1.11:5000 &>/dev/null
      [ "$?" != "0" ] && echo "kube-kadm not ready" && exit 1
   fi
   sudo cp /run/containers/0/auth.json /home/bigred/auth.json; sudo chmod 755 /home/bigred/auth.json
   kubectl create secret generic dkreg -n default --from-file=.dockerconfigjson=/home/bigred/auth.json --type=kubernetes.io/dockerconfi
gjson &>/dev/null
   kubectl create secret generic dkreg -n argo --from-file=.dockerconfigjson=/home/bigred/auth.json --type=kubernetes.io/dockerconfigjs
on &>/dev/null
   kubectl create secret generic dkreg -n wp --from-file=.dockerconfigjson=/home/bigred/auth.json --type=kubernetes.io/dockerconfigjson
 &>/dev/null
   kubectl create secret generic dkreg -n ndb --from-file=.dockerconfigjson=/home/bigred/auth.json --type=kubernetes.io/dockerconfigjso
n &>/dev/null
   kubectl create secret generic dkreg -n jenkins --from-file=.dockerconfigjson=/home/bigred/auth.json --type=kubernetes.io/dockerconfi
gjson &>/dev/null
   kubectl create secret generic dkreg -n kube-system --from-file=.dockerconfigjson=/home/bigred/auth.json --type=kubernetes.io/dockerc
onfigjson &>/dev/null
   echo "dkreg secret ok (namespace: default, jenkins, argo, wp, ndb, kube-system)"

   kubectl patch serviceaccount default -n default -p '{"imagePullSecrets": [{"name": "dkreg"}]}' &>/dev/null
   kubectl patch serviceaccount default -n argo -p '{"imagePullSecrets": [{"name": "dkreg"}]}' &>/dev/null
   kubectl patch serviceaccount default -n wp -p '{"imagePullSecrets": [{"name": "dkreg"}]}' &>/dev/null
   kubectl patch serviceaccount default -n ndb '{"imagePullSecrets": [{"name": "dkreg"}]}' &>/dev/null
   kubectl patch serviceaccount default -n jenkins -p '{"imagePullSecrets": [{"name": "dkreg"}]}' &>/dev/null
   kubectl patch serviceaccount default -n kube-system -p '{"imagePullSecrets": [{"name": "dkreg"}]}' &>/dev/null
   echo "imagePullSecrets ok (namespace: default, jenkins, argo, wp, ndb, kube-system)"

   sudo podman logout 172.22.1.11:5000 &>/dev/null
   sudo rm auth.json
fi

kubectl cp /home/bigred/wulin/bin kube-system/kube-kadm:/home/bigred/wulin -c kadm
kubectl cp /home/bigred/.kube/config kube-system/kube-kadm:/home/bigred/.kube/ -c kadm
kubectl cp /home/bigred/k1/talos/talosconfig kube-system/kube-kadm:/home/bigred/wulin/ -c kadm
echo 'copy .kube/config & bin/system.sh & talosconfig ok'
kubectl cp /home/bigred/wulin/images/ kube-system/kube-kadm:/home/bigred/wulin/ -c kadm
echo "copy wulin/images ok"
kubectl cp /home/bigred/wulin/wkload/ kube-system/kube-kadm:/home/bigred/wulin/ -c kadm
echo "copy wkload yaml ok"
echo

#echo "[Base Images]"
#/home/bigred/wulin/deploy-base-img.sh
#echo "[Application Images]"
#/home/bigred/wulin/deploy-app-img.sh
#echo

if [ "$1" == "basic" ]; then
   exit 0
fi

if [ "$1" == "dt" ]; then
   echo ""; echo "[MinIO MNMD]"
   kubectl apply -f ~/wulin/wkload/minio/mnmd/kube-minio-svc.yaml
   sleep 10
   kubectl apply -f ~/wulin/wkload/minio/mnmd/kube-minio-server.yaml
   sleep 10
   kubectl apply -f ~/wulin/wkload/minio/mnmd/kube-minio-job.yaml
   [ "$?" == "0" ] && echo "MinIO MNMD ok"

   echo ""; echo "[MySQL NDB]"
   kubectl -n ndb create configmap ndb-config --from-file=/home/bigred/wulin/wkload/ndb/config.ini &>/dev/null
   kubectl -n ndb create secret generic ndb-mysqld-root-password --from-literal="password=root"
   kubectl -n ndb create configmap mysql-user --from-file=/home/bigred/wulin/wkload/ndb/users.sql &>/dev/null
   kubectl apply -f ~/wulin/wkload/ndb/.
   [ "$?" == "0" ] && echo "MySQL NDB ok" && exit 0
   exit 1
fi

if [ "$1" == "minio" ]; then
   echo "";echo "[DirectPV]"
   sudo apk add kubectl-krew --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted &>/dev/null
   [ "$?" == "0" ] && echo "kubectl krew ok"
   kubectl krew install directpv &>/dev/null
   kubectl directpv install --node-selector node-role.kubernetes.io/worker=k1 &>/dev/null
   [ "$?" == "0" ] && echo "directpv ok"
   kubectl scale deployment.apps/controller -n directpv --replicas=2

   echo "";echo "[MinIO SNSD]"
   kubectl apply -f ~/wulin/wkload/minio/snsd/miniosnsd.yaml
   [ "$?" == "0" ] && echo "MinIO SNSD ok" && exit 0
   exit 1
fi

if [ "$1" == "cicd" ]; then
   kubectl label node k1w1 "node=jenkins"
   kubectl apply -f ~/wulin/wkload/jenkins/mkdir-job.yaml
   sleep 60
   kubectl -n jenkins apply -f ~/wulin/wkload/jenkins/install.yaml
   kubectl -n jenkins rollout status deployment/jenkins-deployment --timeout=1800s
   [ "$?" == "0" ] && echo "Jenkins ok" && exit 0
   exit 1
fi

if [ "$1" == "hadoop" ]; then
   kubectl apply -f ~/wulin/wkload/hadoop/hadoop.yaml
   [ "$?" == "0" ] && echo "Hadoop ok" && exit 0
   exit 1
fi