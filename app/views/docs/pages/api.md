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

```bash
curl -X POST \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com/image.jpg"}' \
  https://cdn.hackclub.com/api/v4/upload_from_url
```

```javascript
const response = await fetch('https://cdn.hackclub.com/api/v4/upload_from_url', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer sk_cdn_your_key_here',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ url: 'https://example.com/image.jpg' })
});

const { url } = await response.json();
```

## GET /api/v4/me

Get the authenticated user.

```bash
curl -H "Authorization: Bearer sk_cdn_your_key_here" \
  https://cdn.hackclub.com/api/v4/me
```

```json
{
  "id": "usr_abc123",
  "email": "you@hackclub.com",
  "name": "Your Name"
}
```

## Errors

| Status | Meaning |
|--------|---------|
| 400 | Missing required parameters |
| 401 | Invalid or missing API key |
| 404 | Resource not found |
| 422 | Validation failed |

```json
{
  "error": "Missing file parameter"
}
```

## Help

- [#cdn-dev on Slack](https://hackclub.slack.com/archives/C08RYDPS36V)
- [GitHub Issues](https://github.com/hackclub/cdn/issues)
