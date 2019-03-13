#!/bin/bash

##############################################################################
##
##  Travis CI test script
##
##############################################################################

printf "\nmvn -q package\n"
mvn -q package

printf "\nhelm init\n"
helm init

printf "\nhelm install ... name-app\n"
helm install --name name-app \
    --set image.repository=registry.ng.bluemix.net/[your-namespace]/name \
    --set image.tag=1.0-SNAPSHOT \
    --set service.port=9080 \
    --set service.targetPort=9080 \
    --set ssl.enabled=false \
    ibm-charts/ibm-open-liberty


printf "\nhelm install ... ping-app\n"
helm install --name ping-app \
    --set image.repository=registry.ng.bluemix.net/[your-namespace]/ping \
    --set image.tag=1.0-SNAPSHOT \
    --set service.port=9080 \
    --set service.targetPort=9080 \
    --set ssl.enabled=false \
    ibm-charts/ibm-open-liberty


printf "\nsleep 120\n"
sleep 120

printf "\nkubectl get pods\n"
kubectl get pods

GUIDE_IP=`minikube ip`
GUIDE_NAME_PORT=`kubectl get service name-app-ibm-open-libert -o jsonpath="{.spec.ports[0].nodePort}"`
GUIDE_PING_PORT=`kubectl get service ping-app-ibm-open-libert -o jsonpath="{.spec.ports[0].nodePort}"`

printf "\nMinikube IP: $GUIDE_IP\n"
printf "\nName Port: $GUIDE_NAME_PORT\n"
printf "\nPing Port: $GUIDE_PING_PORT\n"

printf "\ncurl http://$GUIDE_IP:$GUIDE_NAME_PORT/api/name\n"
curl http://$GUIDE_IP:$GUIDE_NAME_PORT/api/name

printf "\ncurl http://$GUIDE_IP:$GUIDE_PING_PORT/api/ping/name-service\n"
curl http://$GUIDE_IP:$GUIDE_PING_PORT/api/ping/name-service

printf "\nmvn verify -Ddockerfile.skip=true -Dcluster.ip=$GUIDE_IP\n"
mvn verify -Ddockerfile.skip=true -Dcluster.ip=$GUIDE_IP

printf "\nkubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep name)\n"
kubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep name)

printf "\nkubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep ping)\n" 
kubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep ping)
