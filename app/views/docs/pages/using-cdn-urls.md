---
title: Using CDN URLs
icon: link
order: 2
---

# Using CDN URLs

## URL Structure

```
https://cdn.hackclub.com/{id}/{filename}
```

Requests are 301 redirected to the underlying storage bucket.

## Embedding

### Images

```html
<img src="https://cdn.hackclub.com/019505e2-c85b-7f80-9c31-4b2e5a8d9f12/photo.jpg" alt="">
```

### Links

```html
<a href="https://cdn.hackclub.com/019505e2-d4a1-7c20-8b45-6e3f2a1c8d09/document.pdf">Download</a>
```

### Markdown

```markdown
![](https://cdn.hackclub.com/019505e2-e7f3-7d40-a156-9c4e8b2d1f03/screenshot.png)
```

## Hotlinking

Supported. URLs can be embedded in GitHub, Notion, Discord, Slack, etc.

## Content-Type

Served based on file extension.

## URL Rescue

Lookup endpoint for files migrated from legacy CDNs:

```
GET /rescue?url={original_url}
```

Examples:

```
/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/sdhfksdjfhskdjf.png
/rescue?url=https://cloud-xxxx-hack-club-bot.vercel.app/0awawawa.png
```

Returns 301 redirect to the new CDN URL if found. For image URLs (`.png`, `.jpg`, `.jpeg`), returns an SVG 404 placeholder if not found. Otherwise returns HTTP 404.
