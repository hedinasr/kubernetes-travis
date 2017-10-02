#!/bin/bash
DIR=$(dirname $0)
MANIFESTS_DIR=${DIR}/../manifests/
do_ab() {
  local name=${1:?} target=${2:?}
  sed "s/NAME/${name}/;s,TARGET,${target}," ${MANIFESTS_DIR}/ab.pod.yaml.tmpl |kubectl apply -f -
}

NAME=${1:?}
TARGET=${2:?}
do_ab ${NAME} ${TARGET}
# vim: ts=2 sw=2 si et syntax=sh
