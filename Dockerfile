# Thin deploy wrapper around the upstream reqcore image (open-source ATS,
# github.com/reqcore-inc/reqcore). The only change: curl, which the ECS task
# healthcheck runs against http://localhost:3000/ (node:alpine has no curl).
#
# Upgrading: bump the tag below to the newest upstream release
# (https://github.com/reqcore-inc/reqcore/releases), then cut a release here
# with the same version — CI pushes to ECR and redeploys the prod service.
FROM ghcr.io/reqcore-inc/reqcore:v1.6.0

USER root
RUN apk add --no-cache curl
USER reqcore
