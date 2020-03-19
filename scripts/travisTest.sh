#!/bin/bash

##############################################################################
##
##  Travis CI test script
##
##############################################################################

printf "\nmvn -q package\n"
mvn -q package

docker build -t system:1.0-SNAPSHOT system/.
docker build -t inventory:1.0-SNAPSHOT inventory/.

printf "\nsleep 20\n"
sleep 20

printf "\nhelm repo add ibm-charts https://raw.githubusercontent.com/IBM/charts/master/repo/stable/\n"
helm repo add ibm-charts https://raw.githubusercontent.com/IBM/charts/master/repo/stable/

printf "\nhelm install ... system-app\n"
helm install system-app \
    --set image.repository=system \
    --set image.tag=1.0-SNAPSHOT \
    --set service.name=system-service \
    --set service.port=9080 \
    --set service.targetPort=9080 \
    --set ssl.enabled=false \
    ibm-charts/ibm-open-liberty 

printf "\n sleep 60\n"
sleep 60

printf "\nhelm install ... inventory-app\n"
helm install inventory-app \
    --set image.repository=inventory \
    --set image.tag=1.0-SNAPSHOT \
    --set service.name=inventory-service \
    --set service.port=9080 \
    --set service.targetPort=9080 \
    --set ssl.enabled=false \
    ibm-charts/ibm-open-liberty

printf "\n sleep 60\n"
sleep 60

printf "\nkubectl get pods\n"
kubectl get pods

GUIDE_IP=`minikube ip`
GUIDE_SYSTEM_PORT=`kubectl get service system-service -o jsonpath="{.spec.ports[0].nodePort}"`
GUIDE_INVENTORY_PORT=`kubectl get service inventory-service -o jsonpath="{.spec.ports[0].nodePort}"`

printf "\nMinikube IP: $GUIDE_IP\n"
printf "\nSystem Port: $GUIDE_SYSTEM_PORT\n"
printf "\nInventory Port: $GUIDE_INVENTORY_PORT\n"

printf "\ncurl http://$GUIDE_IP:$GUIDE_SYSTEM_PORT/system/properties\n"
curl http://$GUIDE_IP:$GUIDE_SYSTEM_PORT/system/properties

printf "\ncurl http://$GUIDE_IP:$GUIDE_INVENTORY_PORT/inventory/systems/system-service\n"
curl http://$GUIDE_IP:$GUIDE_INVENTORY_PORT/inventory/systems/system-service

printf "\nmvn failsafe:integration-test -Ddockerfile.skip=true -Dcluster.ip=[ip-address] -Dsystem.node.port=[system-node-port] -Dinventory.node.port=[inventory-node-port]\n"
mvn failsafe:integration-test -Dcluster.ip=$GUIDE_IP -Dsystem.node.port=$GUIDE_SYSTEM_PORT -Dinventory.node.port=$GUIDE_INVENTORY_PORT
mvn failsafe:verify

printf "\nkubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep system)\n"
kubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep system)

printf "\nkubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep inventory)\n" 
kubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep inventory)