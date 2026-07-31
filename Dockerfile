# Thin wrapper over the upstream reqcore image (open-source ATS,
# github.com/reqcore-inc/reqcore). The base is built from upstream SOURCE in CI
# (their ghcr.io package is not publicly pullable — anonymous pulls 401 — so
# Option A "prebuilt image" from SELF-HOSTING.md doesn't work; this is their
# Option B). CI builds upstream's own Dockerfile from a pinned git tag and
# passes the result in as BASE_IMAGE — see .github/workflows/docker-image.yml.
#
# The only addition: curl, which the ECS task healthcheck runs against
# http://localhost:3000/ (node:alpine has no curl).
#
# Upgrading: bump REQCORE_VERSION in the workflow, then cut a release here
# with the same version.
ARG BASE_IMAGE=reqcore-upstream:build
FROM ${BASE_IMAGE}

USER root
RUN apk add --no-cache curl
USER reqcore
