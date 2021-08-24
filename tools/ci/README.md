# CI Test README

This directory contains tools to prepare and use inside the Github Actions CI. 

The Travis Tests are intended to test the behaviour of LaTeXML under different environments using multiple TexLive and Perl versions. 

The different environments can be split into two main categories:

* those with a TeXLive installation
* those without a TeXLive installation

Both scenarios internally run the same test suite (`make test`), however because of the way it is set up the latter one will skip a number of tests. 

## The Testing Docker Images

The different testing environments are defined in `.github/CI.yml` using the `strategy.matrix.include` keys. 
Each testing environment corresponds to a single docker image. 

Each docker image is based on [historic-texlive-docker](https://github.com/tkw1536/historic-texlive-docker).
These come preinstalled with the respective perl version (by using `perlbrew`) and TeXLive versions (via old iso images). 

At testing time GitHub Actions CI then:

* pulls each of the docker images
* mounts the version of LaTeXML to be tested using a volume and finally
* executes the standard test suite inside the resulting container

Using this docker-based setup allows the CI to not spend time on downloading, installing, and configuring individual dependencies; 
instead they can focus on running the test suite itself. 

The CI not using any TeX take around 5 minutes to run, whereas the tests using TeXLive take around 15 minutes. 

## Building && Maintaining the test images

Usually, a Dockerfile is built using a `Dockerfile` and an appropriate `build context` (i.e. a set of files that might be included into the docker image). 
Docker images are build automatically using the `build-all.sh` script inside this folder.

Please note that this script:

* makes use of docker build cache; in case of a clean build it is up to the user to remove all old images & cache first;
* does not perform any magical authentication; and does not publish images to an image registry
* may take several hours to run, depending on speed of the internet connection. 

## Running Tests locally

With this setup it is possible to run each test environment locally using Docker. 

To run a specific test, first either build the appropriate image using the build script or pull it from the GitHub Container Registry: 

    docker pull ghcr.io/tkw1536/latexml-test-runtime:$TEX-$PERL

Not all combinations of perl versions and tex are available. 
The list of available `tags` for the docker image are the same as the ones [list in the historic-texlive-docker README](https://github.com/tkw1536/historic-texlive-docker#images).

Next, you can run the tests by mounting the directory containing your LaTeXML repository into a new container:

    docker run --rm -ti -v /path/to/latexml/repository:/root/latexml ghcr.io/tkw1536/latexml-test-runtime:$TEX-$PERL

All dependencies required by LaTeXML are preinstalled in the container.
To run the tests, you can simply type inside the open shell:

```bash
    perl Makefile.PL
    make test
```
