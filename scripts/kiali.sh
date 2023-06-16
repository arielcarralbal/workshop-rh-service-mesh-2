#!/bin/bash
# https://access.redhat.com/solutions/6650301
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=RH SOLA Inc./CN=rlab.sh' -keyout rlab.sh.key -out rlab.sh.crt
oc create secret tls cliente-certs --key=rlab.sh.key --cert=rlab.sh.crt -n service-mesh-gdsp
