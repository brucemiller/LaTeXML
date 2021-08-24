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
build_image 2021-5.34.0
build_image 2021-5.34
build_image 2021-5
build_image 2021
build_image latest
build_image 2020-5.32.1
build_image 2020-5.32
build_image 2020-5
build_image 2020
build_image 2019-5.30.3
build_image 2019-5.30
build_image 2019-5
build_image 2019
build_image 2018-5.28.3
build_image 2018-5.28
build_image 2018-5
build_image 2018
build_image 2017-5.26.3
build_image 2017-5.26
build_image 2017-5
build_image 2017
build_image 2016-5.24.4
build_image 2016-5.24
build_image 2016-5
build_image 2016
build_image 2015-5.22.4
build_image 2015-5.22
build_image 2015-5
build_image 2015
build_image 2014-5.20.3
build_image 2014-5.20
build_image 2014-5
build_image 2014
build_image 2013-5.18.4
build_image 2013-5.18
build_image 2013-5
build_image 2013
build_image 2012-5.16.3
build_image 2012-5.16
build_image 2012-5
build_image 2012
build_image 2011-5.14.4
build_image 2011-5.14
build_image 2011-5
build_image 2011
build_image 2010-5.12.5
build_image 2010-5.12
build_image 2010-5
build_image 2010
build_image 2009-5.10.1
build_image 2009-5.10
build_image 2009-5
build_image 2009
build_image 2008-5.10.1
build_image 2008-5.10
build_image 2008-5
build_image 2008
build_image none-5.34.0
build_image none-5.34
build_image none-5
build_image none
build_image none-5.32.1
build_image none-5.32
build_image none-5.30.3
build_image none-5.30
build_image none-5.28.3
build_image none-5.28
build_image none-5.26.3
build_image none-5.26
build_image none-5.24.4
build_image none-5.24
build_image none-5.22.4
build_image none-5.22
build_image none-5.20.3
build_image none-5.20
build_image none-5.18.4
build_image none-5.18
build_image none-5.16.3
build_image none-5.16
build_image none-5.14.4
build_image none-5.14
build_image none-5.12.5
build_image none-5.12
build_image none-5.10.1
build_image none-5.10
