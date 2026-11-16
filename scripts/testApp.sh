#!/bin/bash
set -euxo pipefail
./mvnw -version

#../scripts/startMinikube.sh
minikube start
minikube status
#kubectl cluster-info
#kubectl get services --all-namespaces
#kubectl config view
eval "$(minikube docker-env)"

./mvnw -ntp -Dhttp.keepAlive=false \
    -Dmaven.wagon.http.pool=false \
    -Dmaven.wagon.httpconnectionManager.ttlSeconds=120 \
    -q clean package

docker pull -q icr.io/appcafe/open-liberty:kernel-slim-java25-openj9-ubi-minimal

docker build --no-cache -t system:1.0-SNAPSHOT system/.
docker build --no-cache -t inventory:1.0-SNAPSHOT inventory/.

docker images

sed -i 's|us.icr.io/\[your-namespace\]/||g' kubernetes.yaml

cat kubernetes.yaml

kubectl apply -f kubernetes.yaml

sleep 180

kubectl get pods

GUIDE_IP=$(minikube ip)
GUIDE_SYSTEM_PORT=$(kubectl get service system-service -o jsonpath="{.spec.ports[0].nodePort}")
GUIDE_INVENTORY_PORT=$(kubectl get service inventory-service -o jsonpath="{.spec.ports[0].nodePort}")

curl http://"$GUIDE_IP":"$GUIDE_SYSTEM_PORT"/system/properties
curl http://"$GUIDE_IP":"$GUIDE_INVENTORY_PORT"/inventory/systems/system-service

./mvnw -ntp failsafe:integration-test -Dcluster.ip="$GUIDE_IP" -Dsystem.node.port="$GUIDE_SYSTEM_PORT" -Dinventory.node.port="$GUIDE_INVENTORY_PORT"
./mvnw -ntp failsafe:verify

kubectl logs "$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep system)"
kubectl logs "$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep inventory)"

kubectl delete -f kubernetes.yaml

#../scripts/stopMinikube.sh
minikube stop
eval "$(minikube docker-env -u)"

# Clear .m2 cache
rm -rf ~/.m2
