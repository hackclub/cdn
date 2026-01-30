---
title: Storage Quotas
icon: database
order: 4
---

# Storage Quotas

CDN provides free storage for the Hack Club community. Your quota depends on whether you're verified.

## What's My Quota?

| Tier | Per File | Total Storage |
|------|----------|---------------|
| **Unverified** | 10 MB | 50 MB |
| **Verified** | 50 MB | 50 GB |
| **Unlimited** | 200 MB | 300 GB |

**New users start unverified.** Once you verify with Hack Club, you automatically get 50GB.

## Get 50GB Free (Verified Tier)

1. Visit [auth.hackclub.com](https://auth.hackclub.com) and submit your ID for verification
2. Wait for HCA ops to approve your ID (usually takes a day or two)
3. Once approved, sign in to CDN again to automatically unlock 50GB

Your quota upgrades automatically once HCA confirms your verification.

## Check Your Usage

Your homepage shows available storage with a progress bar. You'll see warnings when you hit 80% usage, and uploads will be blocked at 100%.

**Via API:**

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://cdn.hackclub.com/api/v4/me
```

```json
{
  "storage_used": 1048576000,
  "storage_limit": 53687091200,
  "quota_tier": "verified"
}
```

## What Happens When I'm Over Quota?

**Web:** You'll see a red banner and uploads will fail with an error message.

**API:** Returns `402 Payment Required` with quota details:

```json
{
  "error": "Storage quota exceeded",
  "quota": {
    "storage_used": 52428800,
    "storage_limit": 52428800,
    "quota_tier": "unverified",
    "percentage_used": 100.0
  }
}
```

Delete some files from **Uploads** to free up space.