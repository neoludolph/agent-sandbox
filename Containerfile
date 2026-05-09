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

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g \
      @anthropic-ai/claude-code \
      @openai/codex \
      @github/copilot

RUN mkdir -p /opt/cursor-agent \
 && HOME=/opt/cursor-agent bash -o pipefail -c 'curl https://cursor.com/install -fsS | bash' \
 && for bin in /opt/cursor-agent/.local/bin/*; do \
      ln -sf "$bin" "/usr/local/bin/$(basename "$bin")"; \
    done

RUN echo 'source "${SDKMAN_DIR}/bin/sdkman-init.sh"' >> /etc/bash.bashrc

RUN java -version \
 && mvn -version \
 && node --version \
 && npm --version \
 && claude --version \
 && codex --version \
 && cursor-agent --version \
 && copilot --version

ENTRYPOINT []
CMD ["/bin/bash"]
