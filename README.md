<div align="center">
  <img src="https://assets.hackclub.com/flag-standalone.svg" width="100" alt="flag">
  <h1>cdn.hackclub.com</h1>
</div>

<p align="center"><i>Deep under the waves and storms there lies a <a href="https://app.slack.com/client/T0266FRGM/C016DEDUL87">vault</a>...</i></p>

<div align="center">
  <img src="https://files.catbox.moe/6fpj0x.png" width="100%" alt="Banner">
  <p align="center">Banner illustration by <a href="https://gh.maxwofford.com">@maxwofford</a>.</p>

  <a href="https://app.slack.com/client/T0266FRGM/C016DEDUL87">
    <img alt="Slack Channel" src="https://img.shields.io/badge/slack-%23cdn-blue.svg?style=flat&logo=slack">
  </a>
</div>


## 📡 API Usage

- All API endpoints require authentication via `Authorization: Bearer api-token` header
- Use the API_TOKEN from your environment configuration
- Failure to include a valid token will result in 401 Unauthorized responses

### V3 API (Latest)
<img alt="Version 3" src="https://files.catbox.moe/e3ravk.png" align="right" width="300">

**Endpoint:** `POST https://cdn.hackclub.com/api/v3/new`

**Headers:**
```
Authorization: Bearer api-token
Content-Type: application/json
```

**Request Example:**
```bash
curl --location 'https://cdn.hackclub.com/api/v3/new' \
--header 'Authorization: Bearer beans' \
--header 'Content-Type: application/json' \
--data '[
  "https://assets.hackclub.com/flag-standalone.svg",
  "https://assets.hackclub.com/flag-orpheus-left.png"
]'
```

**Response:**
```json
{
  "files": [
    {
      "deployedUrl": "https://hc-cdn.hel1.your-objectstorage.com/s/v3/64a9472006c4472d7ac75f2d4d9455025d9838d6_flag-standalone.svg",
      "file": "0_64a9472006c4472d7ac75f2d4d9455025d9838d6_flag-standalone.svg",
      "sha": "64a9472006c4472d7ac75f2d4d9455025d9838d6",
      "size": 4365
    },
    {
      "deployedUrl": "https://hc-cdn.hel1.your-objectstorage.com/s/v3/d926bfd9811ebfe9172187793a171a5cbcc61992_flag-orpheus-left.png",
      "file": "1_d926bfd9811ebfe9172187793a171a5cbcc61992_flag-orpheus-left.png",
      "sha": "d926bfd9811ebfe9172187793a171a5cbcc61992",
      "size": 8126
    }
  ],
  "cdnBase": "https://hc-cdn.hel1.your-objectstorage.com"
}
```

<details>
<summary>V2 API</summary>

<img alt="Version 2" src="https://files.catbox.moe/uuk1vm.png" align="right" width="300">

**Endpoint:** `POST https://cdn.hackclub.com/api/v2/new`

**Headers:**
```
Authorization: Bearer api-token
Content-Type: application/json
```

**Request Example:**
```json
[
  "https://assets.hackclub.com/flag-standalone.svg",
  "https://assets.hackclub.com/flag-orpheus-left.png"
]
```

**Response:**
```json
{
  "flag-standalone.svg": "https://cdn.example.dev/s/v2/flag-standalone.svg",
  "flag-orpheus-left.png": "https://cdn.example.dev/s/v2/flag-orpheus-left.png"
}
```
</details>

<details>
<summary>V1 API</summary>

<img alt="Version 1" src="https://files.catbox.moe/tnzdfe.png" align="right" width="300">

**Endpoint:** `POST https://cdn.hackclub.com/api/v1/new`

**Headers:**
```
Authorization: Bearer api-token
Content-Type: application/json
```

**Request Example:**
```json
[
  "https://assets.hackclub.com/flag-standalone.svg",
  "https://assets.hackclub.com/flag-orpheus-left.png"
]
```

**Response:**
```json
[
  "https://cdn.example.dev/s/v1/0_flag-standalone.svg",
  "https://cdn.example.dev/s/v1/1_flag-orpheus-left.png"
]
```
</details>

# Technical Details

- **Storage Structure:** `/s/v3/{HASH}_{filename}`
- **File Naming:** `/s/{slackUserId}/{unix}_{sanitizedFilename}`

---

### Additional Endpoints

#### Health Check

**Endpoint:** `GET https://cdn.hackclub.com/api/health`

Returns `{ "status": "ok" }` if the service is running.

---

#### Single URL Upload

**Endpoint:** `POST https://cdn.hackclub.com/api/upload`

Upload a single file from a URL. Supports both raw URL text and JSON body.

**Headers:**
```
Authorization: Bearer api-token
Content-Type: application/json (or text/plain)
X-Download-Authorization: Bearer slack-token (optional, required for Slack files)
```

**Request Example:**
```bash
curl --location 'https://cdn.hackclub.com/api/upload' \
--header 'Authorization: Bearer api-token' \
--header 'Content-Type: application/json' \
--data '"https://example.com/image.png"'
```

**Response:**
```json
{
  "url": "https://hc-cdn.hel1.your-objectstorage.com/s/v3/abc123_image.png",
  "id": "abc123",
  "size": 12345,
  "type": "image/png"
}
```

---

#### Direct File Upload (Single)

**Endpoint:** `POST https://cdn.hackclub.com/api/file`

Upload a file directly via `multipart/form-data`.

**Headers:**
```
Authorization: Bearer api-token
Content-Type: multipart/form-data
```

**Request Example:**
```bash
curl --location 'https://cdn.hackclub.com/api/file' \
--header 'Authorization: Bearer api-token' \
--form 'file=@"/path/to/image.png"'
```

**Response:**
```json
{
  "url": "https://hc-cdn.hel1.your-objectstorage.com/s/v3/abc123_image.png",
  "size": 12345,
  "type": "image/png"
}
```

---

#### Direct File Upload (Bulk)

**Endpoint:** `POST https://cdn.hackclub.com/api/files`

Upload up to 10 files directly via `multipart/form-data`.

**Headers:**
```
Authorization: Bearer api-token
Content-Type: multipart/form-data
```

**Request Example:**
```bash
curl --location 'https://cdn.hackclub.com/api/files' \
--header 'Authorization: Bearer api-token' \
--form 'files=@"/path/to/image1.png"' \
--form 'files=@"/path/to/image2.png"'
```

**Response:**
```json
{
  "files": [
    { "url": "https://hc-cdn.hel1.your-objectstorage.com/s/v3/abc123_image1.png", "size": 12345, "type": "image/png" },
    { "url": "https://hc-cdn.hel1.your-objectstorage.com/s/v3/def456_image2.png", "size": 67890, "type": "image/png" }
  ],
  "cdnBase": "https://hc-cdn.hel1.your-objectstorage.com"
}
```

---

#### Default Upload (V3 Alias)

**Endpoint:** `POST https://cdn.hackclub.com/api/new`

Alias for `/api/v3/new`. Accepts an array of URLs and returns V3 format response.

<div align="center">
  <br>
  <p>Made with 💜 for Hack Club</p>
</div>