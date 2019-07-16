#! /usr/bin/env bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"
export GOPATH=/home/rkeene/devel/perlin/go-fuzz/INST
export PATH="/home/rkeene/devel/perlin/go-fuzz/INST/bin:/opt/go/bin:${PATH}"

if [ ! -f fuzzwavelet-fuzz.zip ]; then
	./rebuild.sh
fi

ulimit -m $[4 * 1024 * 1024]
ulimit -v $[4 * 1024 * 1024]

set +e

(
	staticcheck -f json github.com/perlin-network/wavelet
) | jq -s .
