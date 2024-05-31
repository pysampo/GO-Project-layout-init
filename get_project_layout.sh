#!/bin/sh

set -e

PROJECT_NAME=""
OUT_DIR=./

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
DIRCOUNT=$(find . -maxdepth 1 -type d | wc -l)

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
set -ex

mkdir -p cmd/$PROJECT_NAME \
    internal/controller/$PROJECT_NAME \
    internal/pkg \
    internal/handler/grpc \
    internal/handler/http \
    internal/storage \
    api \
    pkg \
    docker \
    configs

echo "package main" >> cmd/$PROJECT_NAME/main.go

# todo:
if  false; then
    # go mod init
    # go mod tidy
    echo "not impl."
fi

echo $'.vscode\n.swp\nbuild' > .gitignore

cat << EOF > Makefile
.PHONY: run build gen clean

PROJECT_NAME := ${PROJECT_NAME}
BUILD_DIR := ./build
API_DIR := ./api
GEN_DIR := ./pkg/

run:
	go run cmd/\$(PROJECT_NAME)/*.go

build:
	go build -o \$(BUILD_DIR)/\$(PROJECT_NAME) cmd/\$(PROJECT_NAME)/*.go

gen:
	protoc -I=\$(API_DIR) --go_out=\$(GEN_DIR) --go-grpc_out=\$(GEN_DIR) \$(API_DIR)/\$(PROJECT_NAME).proto

.DELETE_ON_ERROR:
clean:
	rm -rf \$(BUILD_DIR) && find \$(GEN_DIR) -type f -name '*.go' -exec rm {} +
EOF
