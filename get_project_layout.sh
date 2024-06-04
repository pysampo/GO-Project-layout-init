#!/bin/sh

set -e

PROJECT_NAME=""
OUT_DIR=./

REGISTRY_HOST=""
SANDBOX_IMAGE="golang"
SANDBOX_TAG="1.21.10-bullseye"

usage() {
 echo "Usage: $0 [OPTIONS]"
 echo "Options:"
 echo " -h, --help     Usage example: ./get_project_layout.sh -n auth"
 echo " -n, --name     Name of project"
 echo " -d, --dir      Directory to output(optional)"
}

has_argument() {
    [[ ("$1" == *=* && -n ${1#*=}) || ( ! -z "$2" && "$2" != -*)  ]];
}

extract_argument() {
  echo "${2:-${1#*=}}"
}

handle_options() {
  if [ $# -eq 0 ]; then
    usage
    exit 1
  fi

  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      -d | --dir)
        if ! has_argument $@; then
          echo "Directory name not specified." >&2
          usage
          exit 1
        fi
        OUT_DIR=$(extract_argument $@)
        shift 2
        ;;
      -n | --name*)
        if ! has_argument $@; then
          echo "Project name not specified." >&2
          usage
          exit 1
        fi
        name=$(extract_argument $@)
        PROJECT_NAME=$(echo "$name" | awk '{print tolower($0)}')
        shift 2
        ;;
      -*)
        echo "Option $1 requires an argument." >&2
        usage
        exit 1
        ;;
      *)
        echo "Invalid option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

handle_options "$@"

if [ -z ${PROJECT_NAME} ]; then
    echo $'Error: expect a project name' >&2
    usage
    exit 1
fi

if [ $d ${OUT_DIR} ]; then
    mkdir -p ${OUT_DIR}
fi

cd $OUT_DIR

FILECOUNT=$(find . -maxdepth 1 -type f | wc -l)
DIRCOUNT=$(find  . -maxdepth 1 -type d | wc -l)

if [ ${DIRCOUNT} -ne 1 ]; then
    echo "Error: ${OUT_DIR} is not empty" >&2
    exit 1
fi
if [ ${OUT_DIR} == "./" ] && [ ${FILECOUNT} -ne 1 ]; then
    echo "Error: ${OUT_DIR} is not empty" >&2
    exit 1
fi
if [ ${OUT_DIR} != "./" ] && [ ${FILECOUNT} -ne 0 ]; then
    echo "Error: ${OUT_DIR} is not empty" >&2
    exit 1
fi
touch example
status=$?
if [ ${status} -ne 0 ]; then
    echo "Error: permission denied" >&2
    exit 1
fi
rm example

echo "Preparing your project \"${PROJECT_NAME}\""
set -x

mkdir -p cmd/$PROJECT_NAME \
    internal/controller/$PROJECT_NAME \
    internal/pkg \
    internal/handler/grpc \
    internal/repository \
    api \
    pkg \
    docker \
    config


echo $'*.o\n.vscode\n.swp\nbuild' > .gitignore
echo $'build\ndocker' > .dockerignore

cat << EOF > cmd/$PROJECT_NAME/main.go
package main

import "fmt"

func main() {
	fmt.Println("Hello, ${PROJECT_NAME}")
}
EOF

cat << EOF > Makefile
.DELETE_ON_ERROR:
.PHONY: run build gen clean

PROJECT_ROOT := \$(shell pwd)
PROJECT_NAME := ${PROJECT_NAME}
BUILD_DIR := ./build
API_DIR := ./api
GEN_DIR := ./pkg/

define docker
	docker run \\
		--rm \\
		--user \$(id -u):\$(id -g) \\
		--workdir /app \\
		--volume \`pwd\`:/app/ \\
		$SANDBOX_IMAGE:$SANDBOX_TAG make \$(1)
endef

run:
	go run cmd/\$(PROJECT_NAME)/*.go

build:
	go build \\
      -o \$(BUILD_DIR)/\$(PROJECT_NAME) \\
      cmd/\$(PROJECT_NAME)/*.go

docker_build:
	\$(call docker,build)

gen:
	protoc -I=\$(API_DIR) \\
      --go_out=\$(GEN_DIR) \\
      --go-grpc_out=\$(GEN_DIR) \\
      \$(API_DIR)/\$(PROJECT_NAME).proto

clean:
	rm -rf \$(BUILD_DIR) && find \$(GEN_DIR) -type f -name '*.go' -exec rm {} +
EOF

cat << EOF > config/$PROJECT_NAME.yml
version: "3"
project:
  name: hello_${PROJECT_NAME}
  environment: development
  service_name: ${PROJECT_NAME}-service

grpc:
  host: 0.0.0.0
  port: 8080
  maxConnectionIdle: 5m
  timeout: 15s
  maxConnectionAge: 5m
EOF

cat << EOF > docker/Dockerfile
FROM $SANDBOX_IMAGE:$SANDBOX_TAG

WORKDIR /app/

COPY cmd      /app/cmd
COPY config   /app/configs
COPY internal /app/internal
COPY pkg      /app/pkg

CMD ["go", "run", "cmd/${PROJECT_NAME}/main.go"]
EOF

cat << EOF > docker-compose.yml
version: "3"
services:
  ${PROJECT_NAME}:
    container_name: hello_${PROJECT_NAME}
    build:
      context: ./
      dockerfile: docker/Dockerfile
    network_mode: "host"
EOF
