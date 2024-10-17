#!/bin/bash
REPOROOT=$(git rev-parse --show-toplevel)

if [ ! -d ${REPOROOT}/deps/public ]; then
	mkdir -p ${REPOROOT}/deps/public
	git clone git@github.com:openconfig/public ${REPOROOT}/deps/public
fi

${HOME}/go/bin/proto_generator \
	-path ${REPOROOT}/deps/public \
	-add_schemapaths \
	-output_dir="${REPOROOT}/v1/proto" \
	-generate_fakeroot=false \
	-exclude_modules=ietf-interfaces,openconfig-interfaces,openconfig-qos,openconfig-platform,openconfig-defined-sets,openconfig-qos,openconfig-qos-types \
	-package_name=openconfig \
	-go_package_base="github.com/openconfig/gsii/v1/proto" \
	${REPOROOT}/v1/yang/qos/gsii-qos-proto.yang
