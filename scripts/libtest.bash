#!/bin/bash

# Copyright (c) 2016-2017 Bitnami
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# k8s helpers, specially "wait"-ers on pod ready/deleted/etc
KUBECTL_BIN=$(which kubectl)
: ${KUBECTL_BIN:?ERROR: missing binary: kubectl}

export TEST_MAX_WAIT_SEC=120

# Workaround 'bats' lack of forced output support, dup() stderr fd
exec 9>&2
echo_info() {
    test -z "$TEST_DEBUG" && return 0
    echo "INFO: $*" >&9
}
export -f echo_info

kubectl() {
    ${KUBECTL_BIN:?} --context=${TEST_CONTEXT:?} "$@"
}

## k8s specific Helper functions
k8s_wait_for_pod_state() {
    local state=${1:?}; shift
    echo_info "Waiting for pod '${@}' to be '${state}' ... "
    local -i cnt=${TEST_MAX_WAIT_SEC:?}
    until kubectl get pod "${@}" |&egrep -q "${state}"; do
        ((cnt=cnt-1)) || return 1
        sleep 1
    done
}
k8s_wait_for_pod_running() {
    k8s_wait_for_pod_state Running "${@}"
}
k8s_wait_for_pod_completed() {
    k8s_wait_for_pod_state Completed -a "${@}"
}
k8s_wait_for_pod_gone() {
    k8s_wait_for_pod_state 'No.resources.found|not.found' "${@}"
}
k8s_wait_for_uniq_pod() {
    echo_info "Waiting for pod '${@}' to be the only one running ... "
    local -i cnt=${TEST_MAX_WAIT_SEC:?}
    until [[ $(kubectl get pod "${@}" -ogo-template='{{.items|len}}') == 1 ]]; do
        ((cnt=cnt-1)) || return 1
        sleep 1
    done
    k8s_wait_for_pod_running "${@}"
    echo_info "Finished waiting"
}
k8s_wait_for_pod_logline() {
    local string="${1:?}"; shift
    local -i cnt=${TEST_MAX_WAIT_SEC:?}
    echo_info "Waiting for '${@}' to show logline '${string}' ..."
    until kubectl logs "${@}"|&grep -q "${string}"; do
        ((cnt=cnt-1)) || return 1
        sleep 1
    done
}
k8s_wait_for_cluster_ready() {
    echo_info "Waiting for k8s cluster to be ready (context=${TEST_CONTEXT}) ..."
    _wait_for_cmd_ok kubectl get po 2>/dev/null && \
    k8s_wait_for_pod_running -n kube-system -l component=kube-addon-manager && \
    k8s_wait_for_pod_running -n kube-system -l k8s-app=kube-dns && \
        return 0
    return 1
}
k8s_log_all_pods() {
    local namespaces=${*:?} ns
    for ns in ${*}; do
        echo_info "### namespace: ${ns} ###"
        kubectl get pod -n ${ns} -oname|xargs -I@ sh -xc "kubectl logs -n ${ns} @|sed 's|^|@: |'"
    done
}
_wait_for_cmd_ok() {
    local cmd="${*:?}"; shift
    local -i cnt=${TEST_MAX_WAIT_SEC:?}
    echo_info "Waiting for '${*}' to successfully exit ..."
    until env ${cmd}; do
        ((cnt=cnt-1)) || return 1
        sleep 1
    done
}

## Entry points used by 'bats' tests:
verify_k8s_tools() {
    local tools="kubectl kubecfg"
    for exe in $tools; do
        which ${exe} >/dev/null && continue
        echo "ERROR: '${exe}' needs to be installed"
        return 1
    done
}
verify_rbac_mode() {
    kubectl api-versions |&grep -q rbac && return 0
    echo "ERROR: Please run w/RBAC, e.g. minikube as: minikube start --extra-config=apiserver.Authorization.Mode=RBAC"
    return 1
}
# vim: sw=4 ts=4 et si
