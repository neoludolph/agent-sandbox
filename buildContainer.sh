#!/bin/bash
set -euo pipefail
docker build -f Containerfile -t agent-sandbox .
