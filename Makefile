.DEFAULT_GOAL := dist/SHA512SUM
.PHONY: clean test

CLIENT_INSTALLER_URL=https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
BUILDROOT_VERSION=2016.05
ACBUILD_VERSION=0.3.1
RKT_VERSION=1.11.0
ACBUILD=build/acbuild
RKT=build/rkt/rkt
NGROK_PROTOCOLS=http https tcp
IMAGES=$(foreach proto, $(NGROK_PROTOCOLS), dist/dit4c-helper-listener-ngrok1-$(proto).linux.amd64.aci)

dist/SHA512SUM: dist/dit4c-helper-listener-ngrok1.linux.amd64.aci $(IMAGES) dist/ngrokd.linux.amd64.aci
	sha512sum $^ | sed -e 's/dist\///' > dist/SHA512SUM

dist/dit4c-helper-listener-ngrok1-%.linux.amd64.aci: dist/dit4c-helper-listener-ngrok1.linux.amd64.aci
	rm -rf .acbuild
	sudo -v
	sudo $(ACBUILD) --debug begin ./dist/dit4c-helper-listener-ngrok1.linux.amd64.aci
	sudo $(ACBUILD) environment add NGROK_PROTOCOL $*
	sudo $(ACBUILD) set-name dit4c-helper-listener-ngrok1-$*
	sudo $(ACBUILD) write --overwrite dist/dit4c-helper-listener-ngrok1-$*.linux.amd64.aci
	sudo $(ACBUILD) end
	sudo chown $(shell id -nu) dist/dit4c-helper-listener-ngrok1-$*.linux.amd64.aci

dist/dit4c-helper-listener-ngrok1.linux.amd64.aci: build/acbuild build/client-base.aci build/ngrok build/jwt *.sh | dist
	rm -rf .acbuild
	sudo -v
	sudo $(ACBUILD) --debug begin ./build/client-base.aci
	sudo $(ACBUILD) environment add DIT4C_INSTANCE_PRIVATE_KEY ""
	sudo $(ACBUILD) environment add DIT4C_INSTANCE_JWT_KID ""
	sudo $(ACBUILD) environment add DIT4C_INSTANCE_JWT_ISS ""
	sudo $(ACBUILD) environment add DIT4C_INSTANCE_HELPER_AUTH_HOST ""
	sudo $(ACBUILD) environment add DIT4C_INSTANCE_HELPER_AUTH_PORT ""
	sudo $(ACBUILD) environment add DIT4C_INSTANCE_URI_UPDATE_URL ""
	sudo $(ACBUILD) environment add NGROK_PROTOCOL ""
	sudo $(ACBUILD) copy build/jwt /usr/bin/jwt
	sudo $(ACBUILD) copy build/ngrok /usr/bin/ngrok
	sudo $(ACBUILD) copy run.sh /opt/bin/run.sh
	sudo $(ACBUILD) copy listen_for_url.sh /opt/bin/listen_for_url.sh
	sudo $(ACBUILD) copy notify_portal.sh /opt/bin/notify_portal.sh
	sudo $(ACBUILD) copy sort_by_latency.sh /opt/bin/sort_by_latency.sh
	sudo $(ACBUILD) set-name dit4c-helper-listener-ngrok1
	sudo $(ACBUILD) set-exec -- /opt/bin/run.sh
	sudo $(ACBUILD) set-user listener
	sudo $(ACBUILD) environment add HOME "/home/listener"
	sudo $(ACBUILD) write --overwrite dist/dit4c-helper-listener-ngrok1.linux.amd64.aci
	sudo $(ACBUILD) end
	sudo chown $(shell id -nu) dist/dit4c-helper-listener-ngrok1.linux.amd64.aci

dist/ngrokd.linux.amd64.aci: build/acbuild build/ngrokd | dist
	rm -rf .acbuild
	$(ACBUILD) --debug begin
	$(ACBUILD) copy build/ngrokd /usr/bin/ngrokd
	$(ACBUILD) set-name ngrokd
	$(ACBUILD) port add ngrok-client-port tcp 4443
	$(ACBUILD) set-exec -- /usr/bin/ngrokd
	$(ACBUILD) write --overwrite dist/ngrokd.linux.amd64.aci
	$(ACBUILD) end

dist:
	mkdir -p dist

build:
	mkdir -p build

build/client-base.aci: $(RKT)
	$(eval RKT_TMPDIR := $(shell mktemp -d -p ./build))
	$(eval RKT_UUID_FILE := $(shell mktemp -p ./build))
	sudo -v && sudo $(RKT) --dir=$(RKT_TMPDIR) \
		run --insecure-options=image --uuid-file-save=$(RKT_UUID_FILE) \
		--dns=8.8.8.8 \
		docker://alpine:edge \
		--exec /bin/sh -- -c \
		"apk add --update bind-tools nmap curl && adduser -D listener && rm -rf /var/cache/apk/*"
	sudo $(RKT) --dir=$(RKT_TMPDIR) export --overwrite `cat $(RKT_UUID_FILE)` $@
	sudo chown $(shell id -nu) build/client-base.aci
	sudo $(RKT) --dir=$(RKT_TMPDIR) gc --grace-period=0s
	sudo rm -rf $(RKT_TMPDIR) $(RKT_UUID_FILE)

build/buildroot: | build
	curl -sL https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz | tar xz -C build
	mv build/buildroot-${BUILDROOT_VERSION} build/buildroot

build/acbuild: | build
	curl -sL https://github.com/appc/acbuild/releases/download/v${ACBUILD_VERSION}/acbuild-v${ACBUILD_VERSION}.tar.gz | tar xz -C build
	mv build/acbuild-v${ACBUILD_VERSION}/acbuild build/acbuild
	-rm -rf build/acbuild-v${ACBUILD_VERSION}

build/ngrok build/ngrokd build/jwt: | $(RKT)
	$(eval RKT_TMPDIR := $(shell mktemp -d -p ./build))
	sudo -v && sudo $(RKT) --dir=$(RKT_TMPDIR) run \
		--dns=8.8.8.8 --insecure-options=image \
    --volume output-dir,kind=host,source=`pwd`/build \
    docker://golang:alpine \
    --set-env CGO_ENABLED=0 \
    --set-env GOOS=linux \
    --mount volume=output-dir,target=/output \
    --exec /bin/sh --  -c "apk add --update git make && /usr/local/go/bin/go get -v --ldflags '-extldflags \"-static\"' github.com/knq/jwt/cmd/jwt && git clone --depth 1 https://github.com/inconshreveable/ngrok.git && cd ngrok && make release-client release-server && install -t /output -o $(shell id -u) -g $(shell id -g) /go/bin/* /go/ngrok/bin/*"
	sudo -v && sudo $(RKT) --dir=$(RKT_TMPDIR) gc --grace-period=0s
	sudo rm -rf $(RKT_TMPDIR)

build/bats: | build
	curl -sL https://github.com/sstephenson/bats/archive/master.zip > build/bats.zip
	unzip -d build build/bats.zip
	mv build/bats-master build/bats
	rm build/bats.zip

$(RKT): | build
	curl -sL https://github.com/coreos/rkt/releases/download/v${RKT_VERSION}/rkt-v${RKT_VERSION}.tar.gz | tar xz -C build
	mv build/rkt-v${RKT_VERSION} build/rkt

test: build/bats $(RKT) dist/dit4c-helper-listener-ngrok1.linux.amd64.aci dist/ngrokd.linux.amd64.aci
	sudo -v && echo "" && build/bats/bin/bats -t test

clean:
	-rm -rf build .acbuild dist
