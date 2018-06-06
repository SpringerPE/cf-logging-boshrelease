#!/usr/bin/env bash
set -o pipefail  # exit if pipe command fails

PROGRAM=${PROGRAM:-$(basename "${BASH_SOURCE[0]}")}
PROGRAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAM_LOG="$(get_logfile)"
PROGRAM_OPTS=$@
CURL=curl
AWK=awk



curl_request() {
  local endpoint="${1}"; shift
  local auth="${1}"; shift
  local url="${1}"; shift

  local cmd="${CURL} -s"

  url="${endpoint%/}/${url}"
  [ -n "${auth}" ] && cmd="${cmd} -u ${auth}"
  ${cmd} -H 'Content-Type: application/json' -w '%{http_code}' "$@" ${url}
  return $?
}


es_add_template() {
  local es="${1}"
  local auth="${2}"
  local name="${3}"
  local content_file="${4}"

  local output_file=$(mktemp)
  local url="_template/${name}"
  local output

  echo_log "Adding template ${name} @${content_file} to ${es}"
  output=$(curl_request "${es}" "${auth}" "${url}" -X PUT -o "${output_file}" --data-binary @"${content_file}" > >(tee -a ${PROGRAM_LOG}) 2> >(tee -a ${PROGRAM_LOG} >&2))
  rvalue=$?
  if [ ${rvalue} != 0 ]
  then
    echo_log "ERROR performing HTTP request: ${rvalue}"
    return ${rvalue}
  fi
  if grep --quiet '"errors":true' "${output_file}"
  then
    echo_log "ERROR performing API operation (HTTP_CODE: ${output}):"
    cat "${output_file}" | tee -a ${PROGRAM_LOG}
  fi
  if [ "${output}" -le 300 ]
  then
    cat "${output_file}" >> ${PROGRAM_LOG}
    echo_log "Ok, template ${name} uploaded"
    output=0
  else
    echo_log "ERROR performing ES operation (HTTP_CODE: ${output}):"
    cat "${output_file}" | tee -a ${PROGRAM_LOG}
  fi
  rm -f "${output_file}"
  return ${output}
}


es_delete_template() {
  local es="${1}"
  local auth="${2}"
  local name="${3}"

  local output_file=$(mktemp)
  local url="_template/${name}"
  local output

  echo_log "Deleting template ${name} from ${es}"
  output=$(curl_request "${es}" "${auth}" "${url}" -X DELETE -o "${output_file}" > >(tee -a ${PROGRAM_LOG}) 2> >(tee -a ${PROGRAM_LOG} >&2))
  rvalue=$?
  if [ ${rvalue} != 0 ]
  then
    echo_log "ERROR performing HTTP request: ${rvalue}"
    return ${rvalue}
  fi
  if grep --quiet '"errors":true' "${output_file}"
  then
    echo_log "ERROR performing API operation (HTTP_CODE: ${output}):"
    cat "${output_file}" | tee -a ${PROGRAM_LOG}
  fi
  if [ "${output}" -le 300 ]
  then
    cat "${output_file}" >> ${PROGRAM_LOG}
    echo_log "Ok, template ${name} deleted"
    output=0
  else
    echo_log "ERROR performing ES operation (HTTP_CODE: ${output}):"
    cat "${output_file}" | tee -a ${PROGRAM_LOG}
  fi
  rm -f "${output_file}"
  return ${output}
}


es_list_templates() {
  local es="${1}"
  local auth="${2}"


  echo_log "Getting list of templates in ${es}:"
  local output_file=$(mktemp)
  output=$(curl_request "${es}" "${auth}" "_cat/templates" -o "${output_file}"  > >(tee -a ${PROGRAM_LOG}) 2> >(tee -a ${PROGRAM_LOG} >&2))
  rvalue=$?
  if [ ${rvalue} != 0 ]
  then
    echo_log "ERROR performing HTTP request: ${rvalue}"
    return ${rvalue}
  fi
  if grep --quiet '"errors":true' "${output_file}"
  then
    echo_log "ERROR performing API operation (HTTP_CODE: ${output}):"
    cat "${output_file}" | tee -a ${PROGRAM_LOG}
  fi
  if [ "${output}" -le 300 ]
  then
    cat "${output_file}" | ${AWK} '{print $1}' | tee -a ${PROGRAM_LOG}
    output=0
  else
    echo_log "ERROR performing ES operation (HTTP_CODE: ${output}):"
    cat "${output_file}" | tee -a ${PROGRAM_LOG}
  fi
  rm -f "${output_file}"
  return ${output}
}


es_delete_all_templates() {
  local es="${1}"; shift
  local auth="${1}"; shift
  local keep=("${@}")

  local delete
  local cmd
  local templates=$(es_list_templates "${es}" "${auth}")
  rvalue=$?
  if [ ${rvalue} != 0 ]
  then
    echo_log "ERROR getting list of templates"
    return ${rvalue}
  fi
  for template in ${templates}
  do
    delete=1
    for i in ${keep[@]}
    do
        if [ "${i}" == "${template}" ]
        then
          delete=0
          break
        fi
    done
    if [ ${delete} == 1 ]
    then
      es_delete_template "${es}" "${auth}" "${template}"
    fi
  done
}


es_update_license() {
  local es="${1}"
  local auth="${2}"
  local license_file="${3}"

  local output_file=$(mktemp)
  local url="_license?acknowledge=true"
  local output

  echo_log "Updating license in ${es} with ${license_file}"
  output=$(curl_request "${es}" "${auth}" "${url}" -X PUT -o "${output_file}" --data-binary @"${license_file}" > >(tee -a ${PROGRAM_LOG}) 2> >(tee -a ${PROGRAM_LOG} >&2))
  rvalue=$?
  if [ ${rvalue} != 0 ]
  then
    echo_log "ERROR performing HTTP request: ${rvalue}"
    return ${rvalue}
  fi
  if grep --quiet '"errors":true' "${output_file}"
  then
    echo_log "ERROR performing API operation (HTTP_CODE: ${output}):"
    cat "${output_file}" | tee -a ${PROGRAM_LOG}
  fi
  if [ "${output}" -le 300 ]
  then
    cat "${output_file}" >> ${PROGRAM_LOG}
    echo_log "Ok, license updated"
    output=0
  else
    echo_log "ERROR performing ES operation (HTTP_CODE: ${output}):"
    cat "${output_file}" | tee -a ${PROGRAM_LOG}
  fi
  rm -f "${output_file}"
  return ${output}
}


es_wait_for_ready() {
  local es="${1}"
  local auth="${2}"
  local max_tries="${3:-5}"
  local timeout="${4:-10m}"

  local counter=1
  echon_log "Waiting for ES cluster ${es} to get ready ... "
  until curl_request "${es}" "${auth}" "_cluster/health?wait_for_status=yellow&timeout=${timeout}" -f >> ${PROGRAM_LOG} 2>&1
  do
    counter=$((counter+1))
    if [ ${counter} -gt ${max_tries} ]
    then
      echo_log "ERROR, ES not ready after ${max_tries} tries"
      return 1
    fi
    sleep 1
    echo -n ". "
  done
  echo
  echo_log "Ready!"
  return 0
}

