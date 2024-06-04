#!/bin/sh

PROJECT_NAME="example"
PROJECT_DIR="./example"

mkdir -p ${PROJECT_DIR}/touch
./get_project_layout.sh --name ${PROJECT_NAME} --dir ${PROJECT_DIR}
status=$?
if [ $status -ne 1 ]; then
    exit 1
fi
rm -rf ${PROJECT_DIR}

./get_project_layout.sh --name ${PROJECT_NAME} --dir ${PROJECT_DIR}
status=$?
if [ $status -ne 0 ]; then
    exit 1
fi

cd ${PROJECT_DIR}

docker-compose build
status=$?
if [ $status -ne 0 ]; then
    exit 1
fi

docker-compose up | grep -I -a "exited with code 0"
status=$?
docker-compose down
rm -rf ${PROJECT_DIR}

if [ $status -ne 0 ]; then
    exit 1
fi
