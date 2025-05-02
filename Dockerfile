ARG BASE_IMAGE
ARG BUILD_IMAGE

FROM ${BUILD_IMAGE} AS fabconnect-builder
RUN apt install make
ADD . /fabconnect
WORKDIR /fabconnect
RUN mkdir /.cache \
    && chgrp -R 0 /.cache \
    && chmod -R g+rwX /.cache
RUN make

FROM alpine:3.19 AS SBOM
WORKDIR /
COPY . /SBOM
RUN apk add --no-cache curl \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin latest \
	&& trivy fs --format spdx-json --output /sbom.spdx.json /SBOM \
    && trivy sbom /sbom.spdx.json --severity UNKNOWN,HIGH,CRITICAL --exit-code 1

FROM $BASE_IMAGE
WORKDIR /fabconnect
RUN chgrp -R 0 /fabconnect/ \
    && chmod -R g+rwX /fabconnect/
COPY --from=fabconnect-builder --chown=1001:0  /fabconnect/fabconnect ./
ADD ./openapi ./openapi/
RUN ln -s /fabconnect/fabconnect /usr/bin/fabconnect
COPY --from=SBOM /sbom.spdx.json /sbom.spdx.json
USER 1001
ENTRYPOINT [ "fabconnect" ]
