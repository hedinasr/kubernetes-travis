#!/usr/bin/env bats

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

load ../scripts/libtest
load ../scripts/cluster_common

: ${TEST_CONTEXT:?}
_get_nginx_content() {
  local configmap=${1:?}
  kubectl get configmap ${configmap} \
    -ogo-template='{{index .data "index.html"}}'
}
# Print -n<NUM> from parsed `ab` run args
_get_ab_num() {
  local pod=${1:?}
  kubectl get pod -a ${pod} -ojsonpath='{.spec.containers[0].args}'| \
    sed -nr 's/.*-n([0-9]+).*/\1/p'
}
_run_ab_pod() {
  local name=${1:?} target=${2:?}
  kubectl delete pod ${name} >& /dev/null || true
  ./scripts/ab.sh ${name} ${target}
  k8s_wait_for_pod_completed -lrun=${name}
}

_verify_ab_pod() {
  local pod=${1:?}
  local num_exp=$(_get_ab_num ${pod})
  kubectl logs ${pod} | egrep -qw Complete.requests:.*${num_exp:?}
}
_verify_content() {
  local url="${1:?}"
  local content_ret
  local content_exp=$(_get_nginx_content my-nginx-content)
  local pod="wget-${RANDOM}"
  kubectl run --restart=Never ${pod} --image=busybox -- wget -qO- ${url}
  k8s_wait_for_pod_completed -lrun=${pod}
  content_ret=$(kubectl logs ${pod})
  kubectl delete pod ${pod}
  [[ ${content_ret} == ${content_exp} ]]
}
# __main__ {
# Verify served content equal to nginx configmap
# Requires SVC_URL and ING_URL env vars (setup by test caller)
@test "Verify expected content via ingress" {
  : ${SVC_URL:?}
  _verify_content ${SVC_URL}
}
@test "Verify expected content via service" {
  : ${ING_URL:?}
  _verify_content ${ING_URL}
}
@test "Launch ab-ing pod via ingress" {
  _run_ab_pod ab-ing ${ING_URL}
}
@test "Launch ab-svc pod via service" {
  _run_ab_pod ab-svc ${SVC_URL}
}
# Verify logged "Complete requests:" matches `ab` run
@test "Verify ab-ing completed requests" {
  _verify_ab_pod ab-ing
}
@test "Verify ab-svc completed requests" {
  _verify_ab_pod ab-svc
}
# }
# vim: ts=2 sw=2 si et syntax=sh
