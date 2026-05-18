# Avatar Lab Prototype

Static prototype for the first wall/avatar client at `home.dinkerwupp.com`.

## What lives here

- `home/` — browser-only prototype with local camera access, MediaPipe face/person detection, and VRM avatar gaze control.
- `deploy-home.sh` — idempotent S3 + CloudFront deployment for `home.dinkerwupp.com`.

## Repo boundary

This directory belongs in `distributed-ai` because it is application/client behavior. Host preparation still belongs in `local-computer-control`, including Pi kiosk setup, SSH access, package installation, and system service management.

## Deployment secrets

`deploy-home.sh` reads AWS credentials from the `distributed-ai` repo root `.env` file. That file is ignored by git. Use `.env.example` for the expected variable names.

## Deploy `home.dinkerwupp.com`

From the `distributed-ai` repo root:

```bash
./prototypes/avatar-lab/deploy-home.sh
```

The script is idempotent. On first run it creates or updates the S3 bucket, uploads `home/`, requests an ACM certificate, and may stop to print the DNS validation CNAME to add in Namecheap. After adding that CNAME, re-run the same command.

When the certificate is issued, the script creates or reuses the CloudFront distribution, updates the private S3 bucket policy for CloudFront OAC, invalidates the cache, and prints the final Namecheap CNAME target for `home.dinkerwupp.com`.

Expected repo-root `.env` keys:

```bash
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
```

The script also accepts standard AWS names, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, if those are already present instead.
