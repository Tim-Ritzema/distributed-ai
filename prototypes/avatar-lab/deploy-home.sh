#!/usr/bin/env bash
# Deploy home.wubblefazz.com → S3 (private) + CloudFront with OAC + ACM cert.
# Idempotent: safe to re-run. Pauses (exits cleanly) if ACM cert needs DNS validation.
#
# On first run:
#   - creates bucket, uploads home/, requests ACM cert
#   - prints CNAME record to add in Namecheap, then exits
# After adding the validation CNAME in Namecheap:
#   - re-run; once cert is ISSUED it creates the CloudFront distribution + bucket policy
#   - prints the final CNAME to add in Namecheap pointing home → <distribution>.cloudfront.net

set -euo pipefail

# --- config ---
DOMAIN="home.wubblefazz.com"
BUCKET="$DOMAIN"
REGION="us-east-1"  # ACM cert MUST be us-east-1 for CloudFront; keeping bucket here too
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_DIR="$SCRIPT_DIR/home"

# --- env: source repo .env, map AWS_ACCESS_KEY/AWS_SECRET_KEY → standard names ---
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
[[ -f "$REPO_ROOT/.env" ]] || { echo "Missing $REPO_ROOT/.env" >&2; exit 1; }
set -a; source "$REPO_ROOT/.env"; set +a
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY:-${AWS_ACCESS_KEY_ID:-}}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_KEY:-${AWS_SECRET_ACCESS_KEY:-}}"
export AWS_DEFAULT_REGION="$REGION"
[[ -n "${AWS_ACCESS_KEY_ID:-}" ]] || { echo "AWS_ACCESS_KEY or AWS_ACCESS_KEY_ID missing in $REPO_ROOT/.env" >&2; exit 1; }
[[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] || { echo "AWS_SECRET_KEY or AWS_SECRET_ACCESS_KEY missing in $REPO_ROOT/.env" >&2; exit 1; }

log()  { printf "\033[1;36m▶\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }

# --- 1. S3 bucket ---
log "Ensuring S3 bucket s3://$BUCKET"
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  ok "Bucket exists"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
  aws s3api put-public-access-block --bucket "$BUCKET" \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  ok "Bucket created (public access blocked)"
fi

# --- 2. Upload site ---
log "Syncing $SITE_DIR → s3://$BUCKET"
aws s3 sync "$SITE_DIR" "s3://$BUCKET" --delete
ok "Site uploaded"

# --- 3. ACM cert (us-east-1) ---
log "Ensuring ACM certificate for $DOMAIN"
CERT_ARN=$(aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" \
  --output text)

if [[ "$CERT_ARN" == "None" || -z "$CERT_ARN" ]]; then
  CERT_ARN=$(aws acm request-certificate --region us-east-1 \
    --domain-name "$DOMAIN" \
    --validation-method DNS \
    --query CertificateArn --output text)
  ok "Cert requested: $CERT_ARN"
  sleep 8  # ACM needs a moment to materialize the validation record
fi

CERT_STATUS=$(aws acm describe-certificate --region us-east-1 \
  --certificate-arn "$CERT_ARN" --query "Certificate.Status" --output text)
log "Cert status: $CERT_STATUS"

if [[ "$CERT_STATUS" != "ISSUED" ]]; then
  echo
  warn "Cert is not yet ISSUED. Add this CNAME in Namecheap, then re-run this script:"
  echo
  aws acm describe-certificate --region us-east-1 --certificate-arn "$CERT_ARN" \
    --query "Certificate.DomainValidationOptions[0].ResourceRecord.{Name:Name,Value:Value,Type:Type}" \
    --output table
  echo
  warn "Namecheap host = the Name minus '.wubblefazz.com.' (the trailing dot too)."
  warn "Namecheap value = the Value minus any trailing dot."
  exit 0
fi
ok "Cert ISSUED"

# --- 4. Origin Access Control ---
OAC_NAME="oac-$BUCKET"
log "Ensuring CloudFront OAC '$OAC_NAME'"
OAC_ID=$(aws cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='$OAC_NAME'].Id | [0]" \
  --output text 2>/dev/null || echo "None")

if [[ "$OAC_ID" == "None" || -z "$OAC_ID" ]]; then
  OAC_ID=$(aws cloudfront create-origin-access-control \
    --origin-access-control-config "Name=$OAC_NAME,Description=OAC for $BUCKET,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3" \
    --query "OriginAccessControl.Id" --output text)
  ok "OAC created: $OAC_ID"
else
  ok "OAC exists: $OAC_ID"
fi

# --- 5. CloudFront distribution ---
log "Ensuring CloudFront distribution for $DOMAIN"
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[?@=='$DOMAIN']].Id | [0]" \
  --output text 2>/dev/null || echo "None")

if [[ "$DIST_ID" == "None" || -z "$DIST_ID" ]]; then
  CALLER_REF="$BUCKET-$(date +%s)"
  S3_ORIGIN_DOMAIN="$BUCKET.s3.$REGION.amazonaws.com"
  CF_CONFIG="$(mktemp -t cf-config.XXXXXX.json)"
  cat > "$CF_CONFIG" <<JSON
{
  "CallerReference": "$CALLER_REF",
  "Aliases": {"Quantity": 1, "Items": ["$DOMAIN"]},
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [{
      "Id": "s3-$BUCKET",
      "DomainName": "$S3_ORIGIN_DOMAIN",
      "OriginAccessControlId": "$OAC_ID",
      "S3OriginConfig": {"OriginAccessIdentity": ""},
      "CustomHeaders": {"Quantity": 0},
      "ConnectionAttempts": 3,
      "ConnectionTimeout": 10
    }]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "s3-$BUCKET",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"], "CachedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"]}},
    "Compress": true,
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "FunctionAssociations": {"Quantity": 0},
    "LambdaFunctionAssociations": {"Quantity": 0},
    "FieldLevelEncryptionId": ""
  },
  "Comment": "$DOMAIN",
  "Enabled": true,
  "ViewerCertificate": {
    "ACMCertificateArn": "$CERT_ARN",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "HttpVersion": "http2",
  "IsIPV6Enabled": true,
  "PriceClass": "PriceClass_100",
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [{
      "ErrorCode": 403,
      "ResponsePagePath": "/index.html",
      "ResponseCode": "200",
      "ErrorCachingMinTTL": 10
    }]
  },
  "Restrictions": {"GeoRestriction": {"RestrictionType": "none", "Quantity": 0}},
  "WebACLId": ""
}
JSON
  DIST_ID=$(aws cloudfront create-distribution --distribution-config "file://$CF_CONFIG" \
    --query "Distribution.Id" --output text)
  rm -f "$CF_CONFIG"
  ok "Distribution created: $DIST_ID"
else
  ok "Distribution exists: $DIST_ID"
fi

# --- 6. S3 bucket policy for OAC ---
log "Updating S3 bucket policy to allow CloudFront OAC"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_FILE="$(mktemp -t bucket-policy.XXXXXX.json)"
cat > "$POLICY_FILE" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCloudFrontServicePrincipal",
    "Effect": "Allow",
    "Principal": {"Service": "cloudfront.amazonaws.com"},
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::$BUCKET/*",
    "Condition": {"StringEquals": {"AWS:SourceArn": "arn:aws:cloudfront::$ACCOUNT_ID:distribution/$DIST_ID"}}
  }]
}
JSON
aws s3api put-bucket-policy --bucket "$BUCKET" --policy "file://$POLICY_FILE"
rm -f "$POLICY_FILE"
ok "Bucket policy updated"

# --- 7. Invalidate CloudFront cache ---
log "Creating CloudFront invalidation for updated site files"
INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*" \
  --query "Invalidation.Id" \
  --output text)
ok "Invalidation created: $INVALIDATION_ID"

# --- 8. Output final DNS record ---
CF_DOMAIN=$(aws cloudfront get-distribution --id "$DIST_ID" --query "Distribution.DomainName" --output text)
CF_STATUS=$(aws cloudfront get-distribution --id "$DIST_ID" --query "Distribution.Status" --output text)
echo
ok "All AWS resources are in place."
echo "  Distribution ID:     $DIST_ID"
echo "  Distribution domain: $CF_DOMAIN"
echo "  Distribution status: $CF_STATUS  (CloudFront 'Deployed' typically ~5-15 min after create)"
echo
warn "Final step: in Namecheap, add this CNAME record on wubblefazz.com:"
echo "  Type:  CNAME"
echo "  Host:  home"
echo "  Value: $CF_DOMAIN"
echo "  TTL:   Automatic"
