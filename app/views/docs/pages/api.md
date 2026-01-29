---
title: API Documentation
icon: code
order: 3
---

# API Documentation 🔧

Want to upload files programmatically? You've come to the right place! Our API lets you integrate CDN uploads directly into your apps.

## Authentication

First, you'll need an API key! Head over to [API Keys](/api_keys) to create one.

Your API key will look something like this:

```
sk_cdn_a1b2c3d4e5f6...
```

**Important**: Copy it immediately after creation—you won't be able to see it again.

### Using Your API Key

Include your API key in the `Authorization` header with the `Bearer` prefix:

```bash
Authorization: Bearer sk_cdn_your_key_here
```

## Endpoints

### GET /api/v4/me

Get information about the currently authenticated user!

**Response:**

```json
{
  "id": "usr_abc123",
  "email": "cat@hackclub.com",
  "name": "Cool Cat"
}
```

**Examples:**

#### cURL

```bash
curl -H "Authorization: Bearer sk_cdn_your_key_here" \
  https://cdn.hackclub.com/api/v4/me
```

#### JavaScript

```javascript
const response = await fetch('https://cdn.hackclub.com/api/v4/me', {
  headers: {
    'Authorization': 'Bearer sk_cdn_your_key_here'
  }
});

const user = await response.json();
console.log(user);
```

#### Ruby

```ruby
require 'faraday'
require 'json'

conn = Faraday.new(url: 'https://cdn.hackclub.com')
response = conn.get('/api/v4/me') do |req|
  req.headers['Authorization'] = 'Bearer sk_cdn_your_key_here'
end

user = JSON.parse(response.body)
puts user
```

---

### POST /api/v4/upload

Upload a file directly! This endpoint accepts multipart form data.

**Parameters:**

- `file` (required): The file to upload

**Response:**

```json
{
  "id": "01234567-89ab-cdef-0123-456789abcdef",
  "filename": "cat.png",
  "size": 12345,
  "content_type": "image/png",
  "url": "https://cdn.hackclub.com/01234567-89ab-cdef-0123-456789abcdef/cat.png",
  "created_at": "2026-01-29T12:00:00Z"
}
```

**Examples:**

#### cURL

```bash
curl -X POST \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  -F "file=@/path/to/cat.png" \
  https://cdn.hackclub.com/api/v4/upload
```

#### JavaScript

```javascript
const formData = new FormData();
formData.append('file', fileInput.files[0]);

const response = await fetch('https://cdn.hackclub.com/api/v4/upload', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer sk_cdn_your_key_here'
  },
  body: formData
});

const upload = await response.json();
console.log('Uploaded to:', upload.url);
```

#### Ruby

```ruby
require 'faraday'
require 'faraday/multipart'
require 'json'

conn = Faraday.new(url: 'https://cdn.hackclub.com') do |f|
  f.request :multipart
  f.adapter Faraday.default_adapter
end

response = conn.post('/api/v4/upload') do |req|
  req.headers['Authorization'] = 'Bearer sk_cdn_your_key_here'
  req.body = {
    file: Faraday::Multipart::FilePart.new(
      '/path/to/cat.png',
      'image/png'
    )
  }
end

upload = JSON.parse(response.body)
puts "Uploaded to: #{upload['url']}"
```

---

### POST /api/v4/upload\_from\_url

Upload a file from a URL. Perfect for grabbing images from the internet.

**Parameters:**

- `url` (required): The URL of the file to upload

**Response:**

```json
{
  "id": "01234567-89ab-cdef-0123-456789abcdef",
  "filename": "image.jpg",
  "size": 54321,
  "content_type": "image/jpeg",
  "url": "https://cdn.hackclub.com/01234567-89ab-cdef-0123-456789abcdef/image.jpg",
  "created_at": "2026-01-29T12:00:00Z"
}
```

**Examples:**

#### cURL

```bash
curl -X POST \
  -H "Authorization: Bearer sk_cdn_your_key_here" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com/cat.jpg"}' \
  https://cdn.hackclub.com/api/v4/upload_from_url
```

#### JavaScript

```javascript
const response = await fetch('https://cdn.hackclub.com/api/v4/upload_from_url', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer sk_cdn_your_key_here',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    url: 'https://example.com/cat.jpg'
  })
});

const upload = await response.json();
console.log('Uploaded to:', upload.url);
```

#### Ruby

```ruby
require 'faraday'
require 'json'

conn = Faraday.new(url: 'https://cdn.hackclub.com')
response = conn.post('/api/v4/upload_from_url') do |req|
  req.headers['Authorization'] = 'Bearer sk_cdn_your_key_here'
  req.headers['Content-Type'] = 'application/json'
  req.body = { url: 'https://example.com/cat.jpg' }.to_json
end

upload = JSON.parse(response.body)
puts "Uploaded to: #{upload['url']}"
```

---

## Error Handling

When something goes wrong, you'll get an error response with details.

**Status Codes:**

- `200 OK` - Success!
- `201 Created` - File uploaded successfully
- `400 Bad Request` - Missing required parameters
- `401 Unauthorized` - Invalid or missing API key
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation failed

**Error Response Format:**

```json
{
  "error": "Missing file parameter"
}
```

Or with validation details:

```json
{
  "error": "Validation failed",
  "details": ["Name can't be blank"]
}
```

---

## Rate Limiting

Be nice to our servers. While we don't enforce strict rate limits yet, please use the API responsibly.

## Need Help?

Got questions? Found a bug? Let us know!

- Join the [#cdn channel on Slack](https://hackclub.enterprise.slack.com/archives/C016DEDUL87)
- Open an issue on [GitHub](https://github.com/hackclub/cdn/issues)

Happy uploading!
