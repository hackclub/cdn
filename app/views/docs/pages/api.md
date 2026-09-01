---
title: API Documentation
icon: code
order: 3
---

# API Documentation

Upload images programmatically using the CDN API.

## Machine-readable spec

The full API surface is published as an OpenAPI 3.2 document:

| Format | URL |
|--------|-----|
| JSON | [https://cdn.hackclub.com/openapi.json](/openapi.json) |
| YAML | [https://cdn.hackclub.com/openapi.yaml](/openapi.yaml) |

It is also served at `/api/openapi.json` and `/api/openapi.yaml`, needs no
authentication, and is linked from every page as
`<link rel="service-desc" href="/openapi.json">`. Point your client generator,
agent, or API console at it rather than scraping this page.

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

## DELETE /api/v4/upload/:id

Delete an uploaded file by its ID.

```bash
curl -X DELETE \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  https://cdn.hackclub.com/api/v4/upload/01234567-89ab-cdef-0123-456789abcdef
```

```javascript
const response = await fetch('https://cdn.hackclub.com/api/v4/upload/01234567-89ab-cdef-0123-456789abcdef', {
  method: 'DELETE',
  headers: { 'Authorization': 'Bearer sk_cdn_your_key_here' }
});

const result = await response.json();
```

**Response:**

```json
{
  "id": "01234567-89ab-cdef-0123-456789abcdef",
  "deleted": true
}
```

Returns 404 if the upload doesn't exist or doesn't belong to you.

## POST /api/v4/uploads

Upload up to 40 files in one request. Partial success is normal: stored files come back in `uploads`, rejected ones in `failed`.

```bash
curl -X POST \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  -F "files[]=@one.png" \
  -F "files[]=@two.png" \
  https://cdn.hackclub.com/api/v4/uploads
```

**Response (201 when at least one file was stored, otherwise 422):**

```json
{
  "uploads": [
    {
      "id": "01234567-89ab-cdef-0123-456789abcdef",
      "filename": "one.png",
      "size": 12345,
      "content_type": "image/png",
      "url": "https://cdn.hackclub.com/01234567-89ab-cdef-0123-456789abcdef/one.png",
      "created_at": "2026-01-29T12:00:00Z"
    }
  ],
  "failed": [
    { "filename": "two.png", "reason": "File exceeds your per-file limit" }
  ]
}
```

## PATCH /api/v4/uploads/:id/rename

Rename an upload. The filename is part of the CDN URL, so the old URL stops resolving — update any references.

```bash
curl -X PATCH \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  -H "Content-Type: application/json" \
  -d '{"filename":"better-name.png"}' \
  https://cdn.hackclub.com/api/v4/uploads/01234567-89ab-cdef-0123-456789abcdef/rename
```

Responds with the updated upload object.

## DELETE /api/v4/uploads/batch

Delete several uploads at once. IDs that aren't yours are reported in `not_found` instead of failing the request.

```bash
curl -X DELETE \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  -H "Content-Type: application/json" \
  -d '{"ids":["01234567-89ab-cdef-0123-456789abcdef"]}' \
  https://cdn.hackclub.com/api/v4/uploads/batch
```

**Response:**

```json
{
  "deleted": [
    { "id": "01234567-89ab-cdef-0123-456789abcdef", "filename": "photo.jpg" }
  ],
  "not_found": ["ffffffff-ffff-ffff-ffff-ffffffffffff"]
}
```

## POST /api/v4/revoke

Revoke the API key making the request. Immediate and irreversible; uploads are untouched.

```bash
curl -X POST \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  https://cdn.hackclub.com/api/v4/revoke
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

Every error is JSON and follows a predictable shape. For example, a missing file parameter returns 400:

```json
{
  "error": "Missing file parameter",
  "code": "missing_parameter",
  "message": "Required parameter `file` is missing or blank.",
  "hint": "Send the file as multipart/form-data under the `file` field, e.g. `curl -F \"file=@photo.jpg\"`.",
  "parameter": "file",
  "status": 400,
  "documentation_url": "https://cdn.hackclub.com/docs/api"
}
```

| Field | Meaning |
| ----- | ------- |
| `code` | Stable machine-readable identifier. Branch on this. |
| `message` | Human-readable description of what went wrong. |
| `hint` | How to resolve it. |
| `status` | HTTP status, repeated for clients that only read the body. |
| `documentation_url` | Where to read more. |
| `error` | Short legacy string, kept for backwards compatibility. Prefer `code`. |
| `details` | Field-level validation messages, when applicable. |
| `parameter` | The offending parameter, when applicable. |
| `error_id` | Support identifier, on server errors. |

| Status | Codes |
| ------ | ----- |
| 400 | `missing_parameter`, `too_many_files` |
| 401 | `invalid_auth` |
| 402 | `quota_exceeded`, `file_too_large` |
| 404 | `not_found`, `upload_not_found`, `route_not_found`, `original_url_not_found` |
| 422 | `validation_failed`, `upload_failed`, `rename_failed` |
| 500 | `internal_error` |

**Quota error (402)** adds a `quota` object:

```json
{
  "error": "Storage quota exceeded",
  "code": "quota_exceeded",
  "message": "This upload would exceed the storage quota for your account (unverified tier).",
  "hint": "Delete files you no longer need, or ask for a higher tier — see https://cdn.hackclub.com/docs/quotas.",
  "quota": {
    "storage_used": 52428800,
    "storage_limit": 52428800,
    "quota_tier": "unverified",
    "percentage_used": 100.0
  },
  "status": 402,
  "documentation_url": "https://cdn.hackclub.com/docs/api"
}
```

Requests to a path that doesn't exist under `/api`, and any request that asks for
JSON with `Accept: application/json`, return `route_not_found` rather than an
HTML 404 page.

See [Storage Quotas](/docs/quotas) for details on getting more space.

## Help

- [#cdn-dev on Slack](https://hackclub.slack.com/archives/C08RYDPS36V)
- [GitHub Issues](https://github.com/hackclub/cdn/issues)
