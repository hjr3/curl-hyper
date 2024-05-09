# curl + hyper

The curl command line tool using hyper as a backend.

## Usage

### Docker

You run run any curl command using the docker container:

`docker run -it --rm hjr3/curl-hyper https://www.example.com`

## Builds

### Docker

- multi-stage build of hyper and curl; then copy over to clean base image
- runs as non-root user: curl_user

Run `just build` to build the container locally
