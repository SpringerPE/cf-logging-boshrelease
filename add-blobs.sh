#!/usr/bin/env bash

SHELL=/bin/bash
AWK=awk
BOSH_CLI=${BOSH_CLI:-bosh}
SRC=$(pwd)/blobs
PREPARE_SCRIPT="prepare"


read_spec_2() {
    local spec="${1}"
    $AWK 'BEGIN {
       url_regex="hola"
    }
    /^files:/ {
        while (getline) {
            if ($1 == "-") {
                if ($3 ~ /#/) {
                    comment=$3$4;
                    where=match(comment, /((http|https|ftp):\/)?\/?([^:\/\s]+)((\/\w+)*\/)([\w\-\.]+[^#?\s]+)([#\w\-\?=]+)?/g, url)
                    print comment
                    print where
                    print url[0]
                    print url[1]
                    if (where != 0) {
                      print $2"@"url[0];
                    }
                }
            } else {
                next;
            }
        }
    }' "$spec"
}


read_spec_blobs() {
    local spec="$1"
    $AWK '/^files:/ {
        while (getline) {
            if ($1 == "-") {
                if ($3 ~ /#/) {
                    url=$3$4;
                    sub(/#/, "", url)
                    print $2"@"url;
                }
            } else {
                next;
            }
        }
    }' "$spec"
}


exec_download_blob() {
    local output="${1}"
    local url="${2}"

    local package=$(dirname "${output}")
    local src=$(basename "${output}")
    (
        cd ${SRC}
        if [ ! -s "${output}" ]
        then
            echo "  Downloading ${url} ..."
            mkdir -p "${package}"
            curl -L -s "${url}" -o "${output}"
        fi
    )
}


exec_prepare() {
    local prepare="${1}"
    (
        echo "* Procesing ${prepare} ..."
        cd ${SRC}
        ${SHELL} "${prepare}"
    )
}


exec_download_spec() {
    local spec="${1}"

    local blob
    local downloadfile
    local downloadurl

    echo "* Procesing specs ${spec} ..."
    for blob in $(read_spec_blobs "${spec}")
    do
        downloadfile=$(echo "${blob}" | cut -d'@' -f 1)
        downloadurl=$(echo "${blob}" | cut -d'@' -f 2)
        exec_download_blob "${downloadfile}" "${downloadurl}"
        exec_bosh_add_blob "${downloadfile}"
    done
}


exec_bosh_add_blob() {
    local blob="$1"
    (
        echo "  Adding blob: ${BOSH_CLI} add-blob $SRC/${blob} ${blob}  ..."
        ${BOSH_CLI} add-blob $SRC/${blob} ${blob}
    )
}


main() {
    for script in $(pwd)/packages/*/spec ; do
        local base=$(dirname "${script}")
        local prepare="${base}/prepare"
        if [ -s "${prepare}" ]; then
            exec_prepare "${prepare}"
        else
            exec_download_spec "${script}"
        fi
    done
}


# Run!
mkdir -p $SRC
main

# echo bosh add-blob blobs/golang/go1.10.linux-amd64.tar.gz   golang/go1.10.linux-amd64.tar.gz

