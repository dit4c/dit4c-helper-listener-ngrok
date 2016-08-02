.DEFAULT_GOAL := dist/SHA512SUM
.PHONY: clean test

CLIENT_INSTALLER_URL=https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
BUILDROOT_VERSION=2016.05
ACBUILD_VERSION=0.3.1
RKT_VERSION=1.11.0
ACBUILD=build/acbuild
NGROK_PROTOCOLS=http https tcp
IMAGES=$(foreach proto, $(NGROK_PROTOCOLS), dist/dit4c-helper-listener-ngrok1-$(proto).linux.amd64.aci)

dist/SHA512SUM: dist/dit4c-helper-listener-ngrok1.linux.amd64.aci $(IMAGES)
	sha512sum $^ | sed -e 's/dist\///' > dist/SHA512SUM

dist/dit4c-helper-listener-ngrok1-%.linux.amd64.aci: dist/dit4c-helper-listener-ngrok1.linux.amd64.aci
	rm -rf .acbuild
	$(ACBUILD) --debug begin ./dist/dit4c-helper-listener-ngrok1.linux.amd64.aci
	$(ACBUILD) environment add NGROK_PROTOCOL $*
	$(ACBUILD) set-name dit4c-helper-listener-ngrok1-$*
	$(ACBUILD) write --overwrite dist/dit4c-helper-listener-ngrok1-$*.linux.amd64.aci
	$(ACBUILD) end

dist/dit4c-helper-listener-ngrok1.linux.amd64.aci: build/acbuild build/rootfs.tar build/ngrok build/jwt *.sh | dist
	rm -rf .acbuild
	$(ACBUILD) --debug begin ./build/rootfs.tar
	$(ACBUILD) environment add DIT4C_INSTANCE_PRIVATE_KEY ""
	$(ACBUILD) environment add DIT4C_INSTANCE_JWT_KID ""
	$(ACBUILD) environment add DIT4C_INSTANCE_JWT_ISS ""
	$(ACBUILD) environment add DIT4C_INSTANCE_HELPER_AUTH_HOST ""
	$(ACBUILD) environment add DIT4C_INSTANCE_HELPER_AUTH_PORT ""
	$(ACBUILD) environment add DIT4C_INSTANCE_URI_UPDATE_URL ""
	$(ACBUILD) environment add NGROK_PROTOCOL ""
	$(ACBUILD) copy build/jwt /usr/bin/jwt
	$(ACBUILD) copy build/ngrok /usr/bin/ngrok
	$(ACBUILD) copy run.sh /opt/bin/run.sh
	$(ACBUILD) copy listen_for_url.sh /opt/bin/listen_for_url.sh
	$(ACBUILD) copy notify_portal.sh /opt/bin/notify_portal.sh
	$(ACBUILD) copy sort_by_latency.sh /opt/bin/sort_by_latency.sh
	$(ACBUILD) set-name dit4c-helper-listener-ngrok1
	$(ACBUILD) set-exec -- /opt/bin/run.sh
	$(ACBUILD) write --overwrite dist/dit4c-helper-listener-ngrok1.linux.amd64.aci
	$(ACBUILD) end

dist:
	mkdir -p dist

build:
	mkdir -p build

build/rootfs.tar: build/buildroot buildroot.config
	cp buildroot.config build/buildroot/.config
	sh -c "cd build/buildroot && make olddefconfig && make -s"
	mv build/buildroot/output/images/rootfs.tar build/

build/buildroot: | build
	curl -sL https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz | tar xz -C build
	mv build/buildroot-${BUILDROOT_VERSION} build/buildroot

build/acbuild: | build
	curl -sL https://github.com/appc/acbuild/releases/download/v${ACBUILD_VERSION}/acbuild-v${ACBUILD_VERSION}.tar.gz | tar xz -C build
	mv build/acbuild-v${ACBUILD_VERSION}/acbuild build/acbuild
	-rm -rf build/acbuild-v${ACBUILD_VERSION}

build/jwt: | build/rkt
	sudo -v && sudo build/rkt/rkt run --dns=8.8.8.8 --insecure-options=image \
    --volume output-dir,kind=host,source=`pwd`/build \
    docker://golang:latest \
    --set-env CGO_ENABLED=0 \
    --set-env GOOS=linux \
    --mount volume=output-dir,target=/output \
    --exec /bin/sh --  -c "apk add --update git && /usr/local/go/bin/go get -v --ldflags '-extldflags \"-static\"' github.com/knq/jwt/cmd/jwt && install -t /output -o $(shell id -u) -g $(shell id -g) /go/bin/jwt"

build/ngrok: | build/rkt
	sudo -v && sudo build/rkt/rkt run --dns=8.8.8.8 --insecure-options=image \
    --volume output-dir,kind=host,source=`pwd`/build \
    docker://golang:latest \
    --set-env CGO_ENABLED=0 \
    --set-env GOOS=linux \
    --mount volume=output-dir,target=/output \
    --exec /bin/sh --  -c "apk add --update git make && git clone --depth 1 https://github.com/inconshreveable/ngrok.git && cd ngrok && make release-client && install -t /output -o $(shell id -u) -g $(shell id -g) /go/ngrok/bin/ngrok"

build/bats: | build
	curl -sL https://github.com/sstephenson/bats/archive/master.zip > build/bats.zip
	unzip -d build build/bats.zip
	mv build/bats-master build/bats
	rm build/bats.zip

build/rkt: | build
	curl -sL https://github.com/coreos/rkt/releases/download/v${RKT_VERSION}/rkt-v${RKT_VERSION}.tar.gz | tar xz -C build
	mv build/rkt-v${RKT_VERSION} build/rkt

test: build/bats build/rkt dist/dit4c-helper-listener-ngrok1.linux.amd64.aci
	sudo -v && echo "" && build/bats/bin/bats --pretty test

clean:
	-rm -rf build .acbuild dist
