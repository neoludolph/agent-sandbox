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
ENV PATH=/usr/local/agent-yolo-bin:${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}

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

RUN mkdir -p /usr/local/agent-yolo-bin \
 && printf '%s\n' \
      '#!/bin/sh' \
      'exec /usr/bin/claude --dangerously-skip-permissions "$@"' \
      > /usr/local/agent-yolo-bin/claude \
 && printf '%s\n' \
      '#!/bin/sh' \
      'exec /usr/bin/codex --dangerously-bypass-approvals-and-sandbox "$@"' \
      > /usr/local/agent-yolo-bin/codex \
 && printf '%s\n' \
      '#!/bin/sh' \
      'exec /usr/bin/copilot --yolo "$@"' \
      > /usr/local/agent-yolo-bin/copilot \
 && printf '%s\n' \
      '#!/bin/sh' \
      'exec /usr/local/bin/cursor-agent --yolo --sandbox disabled --approve-mcps "$@"' \
      > /usr/local/agent-yolo-bin/cursor-agent \
 && printf '%s\n' \
      '#!/bin/sh' \
      'exec /usr/local/bin/agent --yolo --sandbox disabled --approve-mcps "$@"' \
      > /usr/local/agent-yolo-bin/agent \
 && chmod +x /usr/local/agent-yolo-bin/claude \
      /usr/local/agent-yolo-bin/codex \
      /usr/local/agent-yolo-bin/copilot \
      /usr/local/agent-yolo-bin/cursor-agent \
      /usr/local/agent-yolo-bin/agent

RUN printf '%s\n' 'export PATH="/usr/local/agent-yolo-bin:$PATH"' \
      > /etc/profile.d/agent-yolo-path.sh \
 && chmod +x /etc/profile.d/agent-yolo-path.sh \
 && printf '%s\n' \
      'source "${SDKMAN_DIR}/bin/sdkman-init.sh"' \
      'export PATH="/usr/local/agent-yolo-bin:$PATH"' \
      >> /etc/bash.bashrc

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
