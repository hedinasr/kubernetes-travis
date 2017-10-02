#!/bin/bash
DIR=$(dirname $0)
MANIFESTS_DIR=${DIR}/../manifests/
do_kubectl() {
  action=${1:?}
  for i in traefik.{rbac,ds}.yaml; do
    kubectl ${action} -f ${MANIFESTS_DIR}/$i
  done
  for i in my-nginx.{configmap,deployment,svc,ingress}.yaml; do
    kubectl ${action} -f ${MANIFESTS_DIR}/$i
  done
}

do_kubectl $1
# vim: ts=2 sw=2 si et syntax=sh
