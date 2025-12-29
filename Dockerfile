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

FROM alpine:3.21 AS SBOM
WORKDIR /
ADD . /SBOM
RUN apk add --no-cache curl
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.68.2
RUN trivy fs \
  --db-repository public.ecr.aws/aquasecurity/trivy-db \
  --java-db-repository public.ecr.aws/aquasecurity/trivy-java-db \
  --scanners vuln,license \
  --vuln-severity-source nvd,ubuntu,amazon,govulndb,ghsa,nodejs-security-wg,azure,redhat,k8s,debian \
  --sbom-sources oci,rekor \
  --format spdx-json \
  --output /sbom.spdx.json \
  /SBOM

RUN trivy sbom /sbom.spdx.json \
  --db-repository public.ecr.aws/aquasecurity/trivy-db \
  --java-db-repository public.ecr.aws/aquasecurity/trivy-java-db \
  --scanners vuln \
  --vuln-severity-source nvd,ubuntu,amazon,govulndb,ghsa,nodejs-security-wg,azure,redhat,k8s,debian \
  --sbom-sources oci,rekor \
  --severity UNKNOWN,HIGH,CRITICAL \
  --exit-code 1

  RUN trivy sbom /sbom.spdx.json \
  --db-repository public.ecr.aws/aquasecurity/trivy-db \
  --java-db-repository public.ecr.aws/aquasecurity/trivy-java-db \
  --scanners license \
  --sbom-sources oci,rekor \
  --severity HIGH,CRITICAL \
  --exit-code 1

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
