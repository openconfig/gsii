#!/bin/bash

# Copyright 2024 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# To remove the dependency on GOPATH, we locally cache the protobufs that
# we need as dependencies during build time with the intended paths.

if [ -z $SRCDIR ]; then
	THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
	SRC_DIR=${THIS_DIR}/..
fi

mkdir -p ${SRC_DIR}/v1/build_deps/github.com/openconfig/ygot/proto/{ywrapper,yext} 
mkdir -p ${SRC_DIR}/v1/build_deps/github.com/openconfig/gnmi/proto/{gnmi,gnmi_ext}
curl -o ${SRC_DIR}/v1/build_deps/github.com/openconfig/ygot/proto/yext/yext.proto https://raw.githubusercontent.com/openconfig/ygot/master/proto/yext/yext.proto
curl -o ${SRC_DIR}/v1/build_deps/github.com/openconfig/ygot/proto/ywrapper/ywrapper.proto https://raw.githubusercontent.com/openconfig/ygot/master/proto/ywrapper/ywrapper.proto
curl -o ${SRC_DIR}/v1/build_deps/github.com/openconfig/gnmi/proto/gnmi/gnmi.proto https://raw.githubusercontent.com/openconfig/gnmi/master/proto/gnmi/gnmi.proto
curl -o ${SRC_DIR}/v1/build_deps/github.com/openconfig/gnmi/proto/gnmi_ext/gnmi_ext.proto https://raw.githubusercontent.com/openconfig/gnmi/master/proto/gnmi_ext/gnmi_ext.proto

cd ${SRC_DIR}
protoc -I${SRC_DIR} -I ${SRC_DIR}/v1/build_deps --go-grpc_out=. --go-grpc_opt=paths=source_relative --go_out=. --go_opt=paths=source_relative ${SRC_DIR}/v1/proto/gsii/gsii.proto
protoc -I${SRC_DIR} -I ${SRC_DIR}/v1/build_deps --go_out=. --go_opt=paths=source_relative ${SRC_DIR}/v1/proto/openconfig/gsii/v1/interfaces/interfaces.proto
protoc -I${SRC_DIR} -I ${SRC_DIR}/v1/build_deps --go_out=. --go_opt=paths=source_relative ${SRC_DIR}/v1/proto/openconfig/gsii/v1/qos/qos.proto

rm -rf ${SRC_DIR}/v1/build_deps
