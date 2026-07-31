# reqcore (deploy wrapper)

Thin deployment wrapper for [reqcore](https://github.com/reqcore-inc/reqcore),
the open-source ATS (AGPL-3.0). **No application code lives here** — just what
our ECS pattern needs to run the upstream image:

- `.github/workflows/docker-image.yml` — builds upstream from source at the
  pinned `REQCORE_VERSION` tag using upstream's own Dockerfile (their ghcr.io
  package is not publicly pullable, so SELF-HOSTING.md's "prebuilt image"
  path doesn't work), bakes `NUXT_PUBLIC_SITE_URL`, pushes both images
  (linux/arm64) to ECR via OIDC; releases redeploy `reqcore-prod-service`.
- `Dockerfile` — layers `curl` onto the freshly built upstream image (the ECS
  task healthcheck shells out to curl; node:alpine doesn't ship it).
- `nginx/` — the standard nginx sidecar, proxying `127.0.0.1:3000`.

Infrastructure (ECS service, internal ALB, Aurora PostgreSQL, documents S3
bucket, SES SMTP user) is managed in `solomei-infra` (`reqcore.tf`, plus
`module "reqcore"` in `apps.tf`). Runtime env comes from the `prod/reqcore`
Secrets Manager secret. The service is **internal-only**:
<https://reqcore.callimacus.ai> resolves behind the VPN.

## Upgrading reqcore

1. Check the [upstream release notes](https://github.com/reqcore-inc/reqcore/releases).
2. Bump `REQCORE_VERSION` in `.github/workflows/docker-image.yml`.
3. Merge to `main`, then cut a GitHub release here tagged with the same
   upstream version (e.g. `v1.7.0`). CI pushes `:<version>` + `:latest` and
   forces a new prod deployment. Drizzle migrations run automatically when the
   new container boots.

To smoke-test a bump without deploying, run the workflow manually
(`workflow_dispatch`) — images land in the `-ci` ECR repos and nothing deploys.
