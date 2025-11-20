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


## 📡 API Reference

All endpoints require authentication via the `Authorization: Bearer <api-token>` header. Get your API token from the [dashboard](https://cdn.hackclub.com/dashboard).

### Upload File

**Endpoint:** `POST https://cdn.hackclub.com/upload`

**Headers:**
```
Authorization: Bearer <api-token>
Content-Type: application/json
```

**Request:**
```bash
curl -X POST https://cdn.hackclub.com/upload \
  -H "Authorization: Bearer <api-token>" \
  -H "Content-Type: application/json" \
  -d '"https://assets.hackclub.com/flag-standalone.svg"'
```

**Response:**
```json
{
  "deployedUrl": "https://hc-cdn.hel1.your-objectstorage.com/s/64a9472006c4472d7ac75f2d4d9455025d9838d6_flag-standalone.svg",
  "file": "64a9472006c4472d7ac75f2d4d9455025d9838d6_flag-standalone.svg",
  "sha": "64a9472006c4472d7ac75f2d4d9455025d9838d6",
  "size": 4365
}
```

### Delete File

**Endpoint:** `DELETE https://cdn.hackclub.com/api/files/{uuid}`

**Headers:**
```
Authorization: Bearer <api-token>
```

**Request:**
```bash
curl -X DELETE https://cdn.hackclub.com/api/files/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer <api-token>"
```

**Response:**
```
200 OK - File deleted
403 Forbidden - You don't own this file
404 Not Found - File not found
```

**Notes:**
- Replace `{uuid}` with the file's public UUID
- You can only delete files you uploaded
- Deletes from both storage and database

---

### Legacy Endpoints

<details>
<summary>V3 API</summary>

<img alt="Version 3" src="https://files.catbox.moe/e3ravk.png" align="right" width="300">

**Endpoint:** `POST https://cdn.hackclub.com/api/v3/new`

**Headers:**
```
Authorization: Bearer <api-token>
Content-Type: application/json
```

**Request:**
```bash
curl -X POST https://cdn.hackclub.com/api/v3/new \
  -H "Authorization: Bearer <api-token>" \
  -H "Content-Type: application/json" \
  -d '[
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
</details>

<details>
<summary>V2 API</summary>

<img alt="Version 2" src="https://files.catbox.moe/uuk1vm.png" align="right" width="300">

**Endpoint:** `POST https://cdn.hackclub.com/api/v2/new`

**Headers:**
```
Authorization: Bearer <api-token>
Content-Type: application/json
```

**Request:**
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
Authorization: Bearer <api-token>
Content-Type: application/json
```

**Request:**
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

<div align="center">
  <br>
  <p>Made with 💜 for Hack Club</p>
</div>