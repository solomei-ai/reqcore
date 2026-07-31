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

# THE CV-PARSING FIX. Nuxt/Nitro's dependency tracing copies pdfjs-dist's
# entrypoint (pdf.mjs) into .output but NOT pdf.worker.mjs, which pdf.mjs only
# ever loads dynamically. pdfjs then dies with "Setting up fake worker failed",
# CV text extraction yields nothing, and every AI analysis 422s with "No usable
# candidate material" while the UI blames the file ("image-based or corrupted").
# The complete package IS present at /app/node_modules (upstream copies it for
# the seed script), just not on the path pdfjs resolves from.
#
# Verified in this exact image: without the worker getText() returns 0 chars;
# with it, 6633. Re-check after any upstream bump — if Nitro starts tracing the
# worker, this copy becomes a harmless no-op, but if the path changes the
# `test -s` below fails the build instead of shipping a silent regression.
RUN cp /app/node_modules/pdfjs-dist/legacy/build/pdf.worker.mjs \
       /app/.output/server/node_modules/pdfjs-dist/legacy/build/pdf.worker.mjs \
    && test -s /app/.output/server/node_modules/pdfjs-dist/legacy/build/pdf.worker.mjs \
    && chown reqcore:reqcore /app/.output/server/node_modules/pdfjs-dist/legacy/build/pdf.worker.mjs

# @napi-rs/canvas: silences pdfjs's "Cannot load @napi-rs/canvas" warning and
# gives it real DOMMatrix/ImageData/Path2D instead of the degenerate stubs in
# server/utils/resume-parser.ts. Not the cause of the parsing failure above
# (extraction works without it), but the stubs are an identity matrix that
# ignores its arguments, so keep the real implementation available.
#
# Installed in a scratch dir and copied in, rather than `npm install --prefix`
# into .output/server: npm would re-resolve that whole manifest and abort with
# EBADPLATFORM on lightningcss-linux-x64-gnu, a glibc-only optional dep that is
# irrelevant here but fatal on musl.
RUN mkdir -p /tmp/canvas-install \
    && cd /tmp/canvas-install \
    && npm init -y > /dev/null \
    && npm install --omit=dev @napi-rs/canvas \
    && cp -R /tmp/canvas-install/node_modules/@napi-rs /app/.output/server/node_modules/ \
    && rm -rf /tmp/canvas-install \
    && node -e "const c=require('/app/.output/server/node_modules/@napi-rs/canvas'); if(!c.createCanvas) throw new Error('canvas loaded but unusable')" \
    && chown -R reqcore:reqcore /app/.output/server/node_modules/@napi-rs

USER reqcore
