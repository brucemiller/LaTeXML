# Travis Test README

This directory contains tools to prepare and use inside the Travis Tests. 

The Travis Tests are intended to test the behaviour of LaTeXML under different environments using multiple TexLive and Perl versions. 

The different environments can be split into two main categories:

* those with a TeXLive installation
* those without a TeXLive installation

Both scenarios internally run the same test suite (`make test`), however because of the way it is set up the latter one will skip a number of tests. 

## The Testing Docker Images

The different testing environments are defined in `.travis.yml` using the `env` key. 
Each testing environment corresponds to a single docker image. 

Each docker image is based on `Ubuntu Xenial`. 
These come preinstalled with the respective perl version (by using `perlbrew`) and LaTeXML versions (via the package manager). 

At testing time travis then:

* pulls each of the docker images
* mounts the version of LaTeXML to be tested using a volume and finally
* executes the standard test suite inside the resulting container

Using this docker-based setup allows the travis tests to not spend time on downloading, installing, and configuring individual dependencies; 
instead they can focus on running the test suite itself. 

The travis tests not using any TeX take around 5 minutes to run, whereas the tests using LaTeXML take around 15 minutes. 

## Building && Maintaining the test images

Usually, a Dockerfile is built using a `Dockerfile` and an appropriate `build context` (i.e. a set of files that might be included into the docker image). 
Since the travis tests need a set of docker images (one for each combination of perl and tex to be tested), these `Dockerfile`s are created using an automated script. 

The `scripts/build-test-image.sh` takes two arguments (the `TEX` and `PERL` versions to be used), generates a `Dockerfile` into the `dist/$PERL_$TEX` directory, and then builds the docker image. 

For example, to generate a test image for perl `5.22.4` and `texlive-2015` it can be invoked like so:

    bash scripts/build-test-image.sh 5.22.4 texlive-2015

This will build the image `latexml/latexml-test-runtime:5.22.4_texlive-2015`. 


To build all test images required by the tests, the `src/build-all.sh` can be used. 
After building, this script will upload each image to [latexml/latexml-test-runtime](https://hub.docker.com/r/latexml/latexml-test-runtime/) on DockerHub. 

Please note that this script:

* makes use of docker build cache; in case of a clean build it is up to the user to remove all old images & cache first;
* does not perform any magical authentication; instead to upload the images it is required to be a logged into the docker daemon;
* may take several hours to run, depending on speed of the internet connection. 

## Running Tests locally

With this setup it is possible to run each test environment locally using Docker. 

To run a specific test, first either build the appropriate image using the build script or pull it from DockerHub: 

    docker pull latexml/latexml-test-runtime:$PERL_$TEX

Next, you can run the tests by mounting the directory containing your LaTeXML repository into a new container:

    docker run --rm -t -i -v /path/to/latexml/repository:/root/latexml latexml/latexml-test-runtime:$PERL_$TEX

By default, this will run the equivalent of:

    cpanm -v --installdeps --notest .
    perl Makefile.PL && make test

If instead you would liek to run these command manually (e.g. to debug a failed test), run:

    docker run --rm -t -i -v /path/to/latexml/repository:/root/latexml latexml/latexml-test-runtime:$PERL_$TEX /bin/bash

This will start a bash shell inside the Docker container. 
To load the approrpiate version from perlbrew, it is then required to load:

    source /usr/local/perlbrew/etc/bashrc

Afterwards, you can run any test command manually. 