#!/bin/bash
set -e

# cd into the travis/ directory
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# function to build a single image
function build_image() {
    IMAGE="ghcr.io/tkw1536/latexml-test-runtime:$1"
    docker rmi "$IMAGE" || /bin/true
    docker build --build-arg "SRC_TAG=$1" -t "$IMAGE" .
}

# Do the building of all the images
# This might take a bit. 
build_image 2025-5.42
build_image 2024-5.38
build_image 2023-5.38
build_image 2022-5.36
build_image 2021-5.34
build_image none-5.42
build_image none-5.40
build_image none-5.38
build_image none-5.36
build_image none-5.34

# Then remember to publish them by hand if you need them for CI:
#  docker push ghcr.io/tkw1536/latexml-test-runtime:...