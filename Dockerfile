# Thin wrapper over the upstream reqcore image (open-source ATS,
# github.com/reqcore-inc/reqcore). The base is built from upstream SOURCE in CI
# (their ghcr.io package is not publicly pullable — anonymous pulls 401 — so
# Option A "prebuilt image" from SELF-HOSTING.md doesn't work; this is their
# Option B). CI builds upstream's own Dockerfile from a pinned git tag and
# passes the result in as BASE_IMAGE — see .github/workflows/docker-image.yml.
#
# Upgrading: bump REQCORE_VERSION in the workflow, then cut a release here
# with the same version.
ARG BASE_IMAGE=reqcore-upstream:build
FROM ${BASE_IMAGE}

USER root

# curl: the ECS task healthcheck runs `curl -f http://localhost:3000/`
# (node:alpine ships neither curl nor wget).
RUN apk add --no-cache curl

# @napi-rs/canvas: REQUIRED for CV text extraction, despite pdfjs logging its
# absence as a mere "Warning: Cannot load @napi-rs/canvas package".
#
# pdfjs-dist gets DOMMatrix/ImageData/Path2D from this package under Node. When
# it can't load, reqcore's fallback stubs take over (server/utils/resume-parser.ts)
# — and its DOMMatrix is a fixed identity matrix that ignores its constructor
# args, so every glyph transform collapses and getText() returns "". The parser
# then returns null *without throwing*, so nothing is logged as an error and the
# UI just says "Failed to extract text… image-based or corrupted". Every AI
# analysis 422s with "No usable candidate material".
#
# Upstream's image omits it (it's an optional pdfjs peer), so we add it here.
# It goes into .output/server/node_modules because that's where pdfjs resolves
# from — the copy at /app/node_modules is NOT on its resolution path.
#
# Installed in a scratch dir and copied in, rather than `npm install --prefix`
# into .output/server: npm would re-resolve that whole manifest and abort with
# EBADPLATFORM on lightningcss-linux-x64-gnu, a glibc-only optional dep that is
# irrelevant here but fatal on musl. The require() check keeps a broken or
# wrong-arch binary from silently shipping — a silent failure is exactly how
# this bug reached production the first time.
RUN mkdir -p /tmp/canvas-install \
    && cd /tmp/canvas-install \
    && npm init -y > /dev/null \
    && npm install --omit=dev @napi-rs/canvas \
    && mkdir -p /app/.output/server/node_modules \
    && cp -R /tmp/canvas-install/node_modules/@napi-rs /app/.output/server/node_modules/ \
    && rm -rf /tmp/canvas-install \
    && node -e "const c=require('/app/.output/server/node_modules/@napi-rs/canvas'); if(!c.createCanvas) throw new Error('canvas loaded but unusable')" \
    && chown -R reqcore:reqcore /app/.output/server/node_modules/@napi-rs

USER reqcore
