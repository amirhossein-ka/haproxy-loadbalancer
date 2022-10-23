#!/bin/env bash

NETWORK_NAME=local
SUBNET=10.0.0.0/24
IP_RANGE=10.0.0.0/25
NGINX_COUNT=5
IMAGE_NAME="stenote/nginx-hostname:latest"
PORT=80
declare -a NAMES=()


# create network if not exists
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
    docker network create -d bridge \
    --subnet=$SUBNET \
    --ip-range=$IP_RANGE \
    $NETWORK_NAME

#run containers and save their ip's in a array
for ((i = 0; i < $NGINX_COUNT; i++)); do 
    ip="10.0.0.$((i + 2))"
    name="nginx-$i"
    docker container run -d --rm \
        --name "$name" \
        --hostname "$name"\
        --network $NETWORK_NAME \
        --ip $ip \
        $IMAGE_NAME

    NAMES+=("$name")
    echo $ip
done


echo -e "
frontend front
\tbind :80
\tacl root_url path_beg /
\tuse_backend back if root_url

backend back
\tmode http
" > $(pwd)/haproxy_new.cfg


for name in  ${NAMES[@]}; do 
    echo -e "\tserver $name $name:80" >> $(pwd)/haproxy_new.cfg
done


HAPROXY_REPO="haproxy:2.7-dev2-alpine"
docker container run -d --rm \
    --name haproxy \
    --network $NETWORK_NAME \
    -v $(pwd)/haproxy_new.cfg:/usr/local/etc/haproxy/haproxy.cfg \
    --sysctl net.ipv4.ip_unprivileged_port_start=0 \
    -p 8080:80 \
    $HAPROXY_REPO


