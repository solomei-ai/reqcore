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
# Installed into .output/server/node_modules because that's where pdfjs resolves
# from — the copy at /app/node_modules is NOT on its resolution path.
RUN npm install --prefix /app/.output/server --no-save --omit=dev @napi-rs/canvas \
    && node -e "require('/app/.output/server/node_modules/@napi-rs/canvas')" \
    && chown -R reqcore:reqcore /app/.output/server/node_modules

USER reqcore
