#!/bin/bash
set -euxo pipefail

# Set up and start Minikube
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
sudo ln -s $(pwd)/kubectl /usr/local/bin/kubectl
wget https://github.com/kubernetes/minikube/releases/download/v0.28.2/minikube-linux-amd64 -q -O minikube
chmod +x minikube
CHANGE_MINIKUBE_NONE_USER=true

sudo apt-get update -y
sudo apt-get install -y conntrack

sudo minikube start --vm-driver=none --bootstrapper=kubeadm

mvn -q package

docker pull openliberty/open-liberty:kernel-java8-openj9-ubi

docker build -t system:1.0-SNAPSHOT system/.
docker build -t inventory:1.0-SNAPSHOT inventory/.

sleep 20

helm repo add ibm-charts https://raw.githubusercontent.com/IBM/charts/master/repo/stable/

helm install system-app \
    --set image.repository=system \
    --set image.tag=1.0-SNAPSHOT \
    --set service.name=system-service \
    --set service.port=9080 \
    --set service.targetPort=9080 \
    --set ssl.enabled=false \
    ibm-charts/ibm-open-liberty 

sleep 60

helm install inventory-app \
    --set image.repository=inventory \
    --set image.tag=1.0-SNAPSHOT \
    --set service.name=inventory-service \
    --set service.port=9080 \
    --set service.targetPort=9080 \
    --set ssl.enabled=false \
    ibm-charts/ibm-open-liberty

sleep 60

kubectl get pods

GUIDE_IP=$(minikube ip)
GUIDE_SYSTEM_PORT=`kubectl get service system-service -o jsonpath="{.spec.ports[0].nodePort}"`
GUIDE_INVENTORY_PORT=`kubectl get service inventory-service -o jsonpath="{.spec.ports[0].nodePort}"`

curl http://$GUIDE_IP:$GUIDE_SYSTEM_PORT/system/properties
curl http://$GUIDE_IP:$GUIDE_INVENTORY_PORT/inventory/systems/system-service

mvn failsafe:integration-test -Dcluster.ip=$GUIDE_IP -Dsystem.node.port=$GUIDE_SYSTEM_PORT -Dinventory.node.port=$GUIDE_INVENTORY_PORT
mvn failsafe:verify

kubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep system)
kubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep inventory)
