FROM debian:12-slim

ARG JAVA_VERSION=25-amzn
ARG MAVEN_VERSION=3.9.9

ENV SDKMAN_DIR=/opt/sdkman
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      unzip \
      zip \
 && rm -rf /var/lib/apt/lists/*

RUN bash -c 'curl -fsSL "https://get.sdkman.io?rcupdate=false" | bash \
 && source "${SDKMAN_DIR}/bin/sdkman-init.sh" \
 && sdk install java "${JAVA_VERSION}" \
 && sdk install maven "${MAVEN_VERSION}" \
 && sdk flush'

ENV JAVA_HOME=${SDKMAN_DIR}/candidates/java/current
ENV MAVEN_HOME=${SDKMAN_DIR}/candidates/maven/current
ENV PATH=${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g @anthropic-ai/claude-code

RUN echo 'source "${SDKMAN_DIR}/bin/sdkman-init.sh"' >> /etc/bash.bashrc

RUN java -version && mvn -version && claude --version

CMD ["/bin/bash"]
