<div align="center">
  <img src="https://assets.hackclub.com/flag-standalone.svg" width="100" alt="flag">
  <h1>CDN</h1>
  <p>A CDN solution for Hack Club!</p>
</div>

<p align="center"><i>Deep under the waves and storms there lies a <a href="https://app.slack.com/client/T0266FRGM/C016DEDUL87">vault</a>...</i></p>

<div align="center">
  <img src="https://files.catbox.moe/6fpj0x.png" width="100%" alt="Banner">
  <p align="center">Banner illustration by <a href="https://gh.maxwofford.com">@maxwofford</a>.</p>

  <a href="https://app.slack.com/client/T0266FRGM/C016DEDUL87">
    <img alt="Slack Channel" src="https://img.shields.io/badge/slack-%23cdn-blue.svg?style=flat&logo=slack">
  </a>
</div>

## 🚀 Features

- **Multi-version API Support** (v1, v2, v3)
- **Slack Bot Integration**
  - Upload up to 10 files per message
  - Automatic file sanitization
  - file organization
- **Secure API Endpoints**
- **Cost-Effective Storage** (87-98% cost reduction vs. Vercel CDN)
- **Prevent File Deduplication**
- **Organized Storage Structure**

## 🔧 Setup

### 1. Slack App Configuration

1. Create a new Slack App at [api.slack.com](https://api.slack.com/apps)
2. Enable Socket Mode in the app settings
3. Add the following Bot Token Scopes:
   - `channels:history`
   - `channels:read`
   - `chat:write`
   - `files:read`
   - `files:write`
   - `groups:history`
   - `reactions:write`
4. Enable Event Subscriptions and subscribe to `file_shared` event
5. Install the app to your workspace

### 2. Storage Configuration

This CDN supports any S3-compatible storage service. Here's how to set it up using Cloudflare R2 as an example:

#### Setting up Cloudflare R2 (Example)

1. **Create R2 Bucket**
   - Go to Cloudflare Dashboard > R2
   - Click "Create Bucket"
   - Name your bucket
   - Enable public access

2. **Generate API Credentials**
   - Go to R2
   - Click "Manage API tokens" in API
   - Click "Create API Token"
   - Permissions: "Object Read & Write"
   - Save both Access Key ID and Secret Access Key (S3)
   
3. **Get Your URL**
   - Go to R2
   - Click "Use R2 with APIs" in API
   - Select S3 Compatible API
   - The URL is your Endpoint


4. **Configure Custom Domain (Optional)**
   - Go to R2 > Bucket Settings > Custom Domains
   - Add your domain (e.g., cdn.beans.com)
   - Follow DNS configuration steps

### 3. Environment Setup

Check out the `example.env` file for getting started!

### **4. Installation & Running**

#### **Install Dependencies**
Make sure you have [Bun](https://bun.sh/) installed, then run:

```bash
bun install
```

#### **Run the Application**
You can start the application using any of the following methods:

```bash
# Using Node.js
node index.js

# Using Bun
bun index.js

# Using Bun with script
bun run start
```

#### **Using PM2 (Optional)**
For auto-starting the application, you can use PM2:

```bash
pm2 start bun --name "HC-CDN1" -- run start

# Optionally, save the process list
pm2 save

# Optionally, generate startup script
pm2 startup
```

## 📡 API Usage

⚠️ **IMPORTANT SECURITY NOTE**:
- All API endpoints require authentication via `Authorization: Bearer api-token` header
- This includes all versions (v1, v2, v3) - no exceptions!
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
  "https://assets.hackclub.com/flag-orpheus-left.png",
  "https://assets.hackclub.com/icon-progress-marker.svg"
]'
```

**Response:**
```json
{
  "files": [
    {
      "deployedUrl": "https://cdn.example.dev/s/v3/3e48b91a4599a3841c028e9a683ef5ce58cea372_flag-standalone.svg",
      "file": "0_16361167e11b0d172a47e726b40d70e9873c792b_upload_1736985095691",
      "sha": "16361167e11b0d172a47e726b40d70e9873c792b",
      "size": 90173
    },
    {
      "deployedUrl": "https://cdn.example.dev/s/v3/4e48b91a4599a3841c028e9a683ef5ce58cea372_flag-orpheus-left.png",
      "file": "1_16361167e11b0d172a47e726b40d70e9873c792b_upload_1736985095692",
      "sha": "16361167e11b0d172a47e726b40d70e9873c792b",
      "size": 80234
    },
    {
      "deployedUrl": "https://cdn.example.dev/s/v3/5e48b91a4599a3841c028e9a683ef5ce58cea372_icon-progress-marker.svg",
      "file": "2_16361167e11b0d172a47e726b40d70e9873c792b_upload_1736985095693",
      "sha": "16361167e11b0d172a47e726b40d70e9873c792b",
      "size": 70345
    },
    {
      "deployedUrl": "https://cdn.example.dev/s/v3/6e48b91a4599a3841c028e9a683ef5ce58cea372_flag-orpheus-right.png",
      "file": "3_16361167e11b0d172a47e726b40d70e9873c792b_upload_1736985095694",
      "sha": "16361167e11b0d172a47e726b40d70e9873c792b",
      "size": 60456
    }
  ],
  "cdnBase": "https://cdn.example.dev"
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
  "https://assets.hackclub.com/flag-orpheus-left.png",
  "https://assets.hackclub.com/icon-progress-marker.svg"
]
```

**Response:**
```json
{
  "flag-standalone.svg": "https://cdn.example.dev/s/v2/flag-standalone.svg",
  "flag-orpheus-left.png": "https://cdn.example.dev/s/v2/flag-orpheus-left.png",
  "icon-progress-marker.svg": "https://cdn.example.dev/s/v2/icon-progress-marker.svg"
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
  "https://assets.hackclub.com/flag-orpheus-left.png",
  "https://assets.hackclub.com/icon-progress-marker.svg"
]
```

**Response:**
```json
[
  "https://cdn.example.dev/s/v1/0_flag-standalone.svg",
  "https://cdn.example.dev/s/v1/1_flag-orpheus-left.png",
  "https://cdn.example.dev/s/v1/2_icon-progress-marker.svg"
]
```
</details>

## 🤖 Slack Bot Features

- **Multi-file Upload:** Upload up to 10 files in a single message no more than 3 messages at a time!
- **File Organization:** Files are stored as `/s/{slackUserId}/{timestamp}_{sanitizedFilename}`
- **Error Handling:** Error Handeling
- **File Sanitization:** Automatic filename cleaning
- **Size Limits:** Enforces files to be under 2GB

## Legacy API Notes
- V1 and V2 APIs are maintained for backwards compatibility
- All versions now require authentication via Bearer token
- We recommend using V3 API for new implementations

## Technical Details

- **Storage Structure:** `/s/v3/{HASH}_{filename}`
- **File Naming:** `/s/{slackUserId}/{unix}_{sanitizedFilename}`
- **Cost Efficiency:** Uses object storage for significant cost savings
- **Security:** Token-based authentication for API access

## 💻 Slack Bot Behavior

- Reacts to file uploads with status emojis:
  - ⏳ Processing
  - ✅ Success
  - ❌ Error
- Supports up to 10 files per message
- Max 3 messages concurrently!
- Maximum file size: 2GB per file

## 💰 Cost Optimization

- Uses Object storage
- 87-98% cost reduction compared to Vercel CDN

<div align="center">
  <br>
  <p>Made with 💜 for Hack Club</p>
  <p>All illustrations by <a href="https://gh.maxwofford.com">@maxwofford</a></p>
</div>