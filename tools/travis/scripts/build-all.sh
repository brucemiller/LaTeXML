#!/bin/bash
set -e

# cd into the travis/ directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
cd "$DIR/.."

# function to build a single image
function build_image() {
    IMAGE="latexml/latexml-test-runtime:$1_$2"
    docker rmi "$IMAGE" || /bin/true
    /bin/bash ./scripts/build-test-image.sh "$1" "$2"
    docker push "$IMAGE"
}

# Do the building of all the images
# This might take a bit. 
build_image 5.28.0 none
build_image 5.26.2 none
build_image 5.24.4 none
build_image 5.20.3 none
build_image 5.14.4 none
build_image 5.28.0 texlive-2018
build_image 5.26.2 texlive-2016
build_image 5.22.4 texlive-2015