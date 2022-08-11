#!/bin/bash

cantidadDeRequests=$1

if [ $# -eq 0 ]
then
	let "cantidadDeRequests = 10"
	echo "Ejemplo de uso:"
	echo "    request.sh [CANTIDAD]"
	echo "Por defecto: request.sh 10"
	echo " "
fi
	let "i = 0"
	echo "Realizando $cantidadDeRequests Requests..."
	while [ $i -lt $cantidadDeRequests ]; do
  		curl -o /dev/null -s -w "%{http_code}\n" https://$GATEWAY_URL/productpage --insecure
		sleep 2
		let "i=$((i + 1))"
	done

