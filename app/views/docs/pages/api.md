---
title: API Documentation
icon: code
order: 3
---

# API Documentation

Upload images programmatically using the CDN API.

## Authentication

Create an API key at [API Keys](/api_keys). Keys are shown once, so copy it immediately.

Include the key in the `Authorization` header:

```
Authorization: Bearer sk_cdn_your_key_here
```

## POST /api/v4/upload

Upload a file via multipart form data.

```bash
curl -X POST \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  -F "file=@photo.jpg" \
  https://cdn.hackclub.com/api/v4/upload
```

```javascript
const formData = new FormData();
formData.append('file', fileInput.files[0]);

const response = await fetch('https://cdn.hackclub.com/api/v4/upload', {
  method: 'POST',
  headers: { 'Authorization': 'Bearer sk_cdn_your_key_here' },
  body: formData
});

const { url } = await response.json();
```

**Response:**

```json
{
  "id": "01234567-89ab-cdef-0123-456789abcdef",
  "filename": "photo.jpg",
  "size": 12345,
  "content_type": "image/jpeg",
  "url": "https://cdn.hackclub.com/01234567-89ab-cdef-0123-456789abcdef/photo.jpg",
  "created_at": "2026-01-29T12:00:00Z"
}
```

## POST /api/v4/upload\_from\_url

Upload an image from a URL.

**Optional header:** `X-Download-Authorization` — passed as `Authorization` when fetching the source URL (useful for protected resources).

```bash
curl -X POST \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com/image.jpg"}' \
  https://cdn.hackclub.com/api/v4/upload_from_url

# With authentication for the source URL:
curl -X POST \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  -H "X-Download-Authorization: Bearer source_token_here" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://protected.example.com/image.jpg"}' \
  https://cdn.hackclub.com/api/v4/upload_from_url
```

```javascript
const response = await fetch('https://cdn.hackclub.com/api/v4/upload_from_url', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer sk_cdn_your_key_here',
    'Content-Type': 'application/json',
    // Optional: auth for the source URL
    'X-Download-Authorization': 'Bearer source_token_here'
  },
  body: JSON.stringify({ url: 'https://example.com/image.jpg' })
});

const { url } = await response.json();
```

## GET /api/v4/me

Get the authenticated user and quota information.

```bash
curl -H "Authorization: Bearer sk_cdn_your_key_here" \
  https://cdn.hackclub.com/api/v4/me
```

```json
{
  "id": "usr_abc123",
  "email": "you@hackclub.com",
  "name": "Your Name",
  "storage_used": 1048576000,
  "storage_limit": 53687091200,
  "quota_tier": "verified"
}
```

**Quota fields:**
- `storage_used` — bytes used
- `storage_limit` — bytes allowed
- `quota_tier` — `"unverified"`, `"verified"`, or `"functionally_unlimited"`

## Errors

| Status | Meaning |
|--------|---------|
| 400 | Missing required parameters |
| 401 | Invalid or missing API key |
| 402 | Storage quota exceeded |
| 404 | Resource not found |
| 422 | Validation failed |

**Standard error:**

```json
{
  "error": "Missing file parameter"
}
```

**Quota error (402):**

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

See [Storage Quotas](/docs/quotas) for details on getting more space.

## Help

- [#cdn-dev on Slack](https://hackclub.slack.com/archives/C08RYDPS36V)
- [GitHub Issues](https://github.com/hackclub/cdn/issues)
