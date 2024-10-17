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
	-exclude_modules=ietf-interfaces,openconfig-interfaces \
	-package_name=openconfig \
	${REPOROOT}/v1/yang/interfaces/gsii-interfaces-proto.yang
