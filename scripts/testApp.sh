#!/bin/bash
set -euxo pipefail

../scripts/startMinikube.sh

mvn -ntp -Dhttp.keepAlive=false \
    -Dmaven.wagon.http.pool=false \
    -Dmaven.wagon.httpconnectionManager.ttlSeconds=120 \
    -q clean package

docker pull icr.io/appcafe/open-liberty:kernel-slim-java11-openj9-ubi

docker build --no-cache -t system:1.0-SNAPSHOT system/.
docker build --no-cache -t inventory:1.0-SNAPSHOT inventory/.

sed -i 's|us.icr.io/\[your-namespace\]/||g' kubernetes.yaml
sed -i 's=nodePort: 31000==g' kubernetes.yaml
sed -i 's=nodePort: 32000==g' kubernetes.yaml

kubectl apply -f kubernetes.yaml

sleep 120

kubectl get pods

GUIDE_IP=$(minikube ip)
GUIDE_SYSTEM_PORT=$(kubectl get service system-service -o jsonpath="{.spec.ports[0].nodePort}")
GUIDE_INVENTORY_PORT=$(kubectl get service inventory-service -o jsonpath="{.spec.ports[0].nodePort}")

# if the following curl failed, wait for another 3 minutes
curl http://"$GUIDE_IP":"$GUIDE_SYSTEM_PORT"/system/properties || sleep 180; kubectl get pods
curl http://"$GUIDE_IP":"$GUIDE_SYSTEM_PORT"/system/properties || sleep 300; kubectl get pods
curl http://"$GUIDE_IP":"$GUIDE_SYSTEM_PORT"/system/properties || kubectl delete -f kubernetes.yaml; ../scripts/stopMinikube.sh
curl http://"$GUIDE_IP":"$GUIDE_INVENTORY_PORT"/inventory/systems/system-service

mvn failsafe:integration-test -Dcluster.ip="$GUIDE_IP" -Dsystem.node.port="$GUIDE_SYSTEM_PORT" -Dinventory.node.port="$GUIDE_INVENTORY_PORT"
mvn failsafe:verify

kubectl logs "$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep system)"
kubectl logs "$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep inventory)"

kubectl delete -f kubernetes.yaml

../scripts/stopMinikube.sh

# Clear .m2 cache
rm -rf ~/.m2
