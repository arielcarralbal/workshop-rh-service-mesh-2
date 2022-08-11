#!/bin/bash

echo "Generando infinitos requests..."

while true; do 
  curl -o /dev/null -s -w "%{http_code}\n" https://$GATEWAY_URL/productpage --insecure
  sleep 2
done
