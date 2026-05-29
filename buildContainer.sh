#!/bin/bash
set -euo pipefail
docker build --no-cache -f Containerfile -t agent-sandbox .
