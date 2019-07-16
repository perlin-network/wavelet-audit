#! /usr/bin/env bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"
export GOPATH=/home/rkeene/devel/perlin/go-fuzz/INST
export PATH="/home/rkeene/devel/perlin/go-fuzz/INST/bin:/opt/go/bin:${PATH}"

rm -rf crashers fuzzwavelet-fuzz.zip fuzzwavelet-fuzz-libfuzz fuzzwavelet-fuzz.a suppressions

go-fuzz-build fuzzwavelet
#go-fuzz-build -libfuzzer fuzzwavelet
