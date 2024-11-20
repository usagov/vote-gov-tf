#!/usr/bin/env bash
set -e
declare -a envs=("test" "dev" "stage" "prod")
cert_path="../sso_assertion_certs/"
for i in "${envs[@]}"
do
  mkdir -p $cert_path/$i/
  touch $cert_path/$i/sp.cert
  touch $cert_path/$i/sp.key
  openssl req -new -x509 -days 3652 -nodes -out $cert_path/$i/sp.crt -keyout $cert_path/$i/sp.key -batch -config ./sso-assertion-cert-conifiguration.conf
  spkeyf=$(awk 'NF {sub(/\r/, ""); printf "%s\\n      ",$0;}' $cert_path/$i/sp.key)
  echo "$spkeyf" > $cert_path/$i/sp_oneline.key
  spcrtf=$(awk 'NF {sub(/\r/, ""); printf "%s\\n      ",$0;}' $cert_path/$i/sp.crt)
  echo "$spcrtf" > $cert_path/$i/sp_oneline.crt
done
