# frozen_string_literal: true

# The agent instruction file served at /llms.txt, following the llms.txt spec
# (https://llmstxt.org): an H1 title, a blockquote summary, free-form markdown
# with no headings, then H2 sections whose bodies are *only* link lists. The
# reference parser rejects prose under an H2, so guidance lives in the free-form
# region and every H2 body is a list of `- [name](url): description` lines.
#
# This is the "when to use this" document for agents. Keep it concrete: which
# jobs the CDN is the right tool for, which it is not, and exactly how to call
# it. Facts that exist in code (quotas, batch limits, API version, doc pages)
# are read from that code so this file cannot drift away from the service.
class LlmsTxt
  GITHUB_URL = "https://github.com/hackclub/cdn"
  SLACK_URL = "https://hackclub.slack.com/archives/C08RYDPS36V"
  HACK_CLUB_URL = "https://hackclub.com"
  AUTH_URL = "https://auth.hackclub.com"

  class << self
    def host = CDNHost.host

    def base_url = CDNHost.base_url

    def to_s
      [ header, guidance, when_to_use, api, docs, optional ].join("\n")
    end

    private

    # H1 + blockquote summary + the free-form region.
    def header
      <<~MARKDOWN
        # Hack Club CDN

        > File hosting for Hack Clubbers. Upload a file over HTTP and get back a permanent `#{base_url}/<uuid>/<filename>` URL you can hotlink anywhere.

        Hack Club CDN is a file host operated by Hack Club for the Hack Club community. Any file type is accepted, uploads are immutable, URLs do not expire, and hotlinking is allowed. A CDN URL redirects to the storage bucket; there is no directory index and no way to enumerate anyone's files.

        Access is never anonymous. A human signs in with Hack Club Auth and creates an API key at #{base_url}/api_keys; an agent cannot register an account or mint a key on its own. Every `/api/v4` request carries `Authorization: Bearer sk_cdn_...`, acts as the key's owner, and counts against that owner's storage quota.

        The complete machine-readable API description is an OpenAPI #{OpenAPISpec::SPEC_VERSION} document at #{base_url}/openapi.json (API version #{OpenAPISpec::API_VERSION}, no authentication required). Read it instead of scraping the HTML docs. The "When to use this" section below names the jobs this service is the right tool for.
      MARKDOWN
    end

    def guidance
      [ when_not_to_use, how_to_call, endpoints, limits, errors ].join("\n")
    end

    def when_not_to_use
      <<~MARKDOWN
        **When not to use this.** Pick something else if the task is:

        - Anything private, secret, or personal. Every CDN URL is public to whoever holds it. IDs are unguessable UUIDv7 values, but delivery is unauthenticated. Do not upload credentials, private keys, unredacted personal data, or anything the user would not paste into a public channel.
        - Content whose URL must stay the same while the bytes change. Uploads are immutable, and a rename changes the URL and breaks existing links. Upload a new file instead of expecting an in-place update.
        - A user outside Hack Club, or any flow with no API key. There is no anonymous upload endpoint and no self-service signup for agents. Without a key from the user, stop and ask for one.
        - Listing or searching a user's library programmatically. `/api/v4` has no index endpoint; the dashboard at #{base_url}/uploads is the only file listing and it needs a browser session. Record upload IDs when you create them.
        - Bulk archival, backups, or hosting for a commercial product. Quotas are small on purpose and this is a community service, not general-purpose object storage.
        - Finding a file the CDN never had. A miss on `GET /rescue` is a miss; it does not search the web.
      MARKDOWN
    end

    def how_to_call
      <<~MARKDOWN
        **How to call it.**

        1. Get a key from the user. Keys look like `sk_cdn_...` and are shown once at #{base_url}/api_keys. Never invent, guess, or reuse another user's key; if the user has no key, link them there.
        2. Send it as a bearer token on every `/api/v4` request: `Authorization: Bearer sk_cdn_...`. A missing or bad key returns `401` with `"code": "invalid_auth"`.
        3. Upload with multipart form data — a single file under the field `file`, a batch under the repeated field `files[]`.

        ```bash
        curl -X POST #{base_url}/api/v4/upload \\
          -H "Authorization: Bearer sk_cdn_..." \\
          -F "file=@diagram.png"
        ```

        ```json
        {
          "id": "01927c1a-8f4e-7b3a-9c2d-5e6f7a8b9c01",
          "filename": "diagram.png",
          "size": 20481,
          "content_type": "image/png",
          "url": "#{base_url}/01927c1a-8f4e-7b3a-9c2d-5e6f7a8b9c01/diagram.png",
          "created_at": "2026-01-29T12:00:00Z"
        }
        ```

        4. Use the `url` field verbatim, and keep the `id` in case the file is later renamed or deleted. Do not assemble CDN URLs by hand.
        5. Mirror a remote file with `POST /api/v4/upload_from_url` and a JSON body of `{"url": "https://..."}`. Add `X-Download-Authorization` if the source needs its own credentials. Private, loopback, and link-local addresses are rejected, so localhost and internal hosts will not work.
        6. Branch on the `code` field of errors, never on prose. Retry only what is retryable: a `402` means free space or ask for a larger quota, a `400` or `422` means fix the request.
        7. Be a good citizen. There is no published rate limit: batch instead of looping, do not re-upload a file you already have a URL for, and do not poll.
      MARKDOWN
    end

    def endpoints
      <<~MARKDOWN
        **Endpoints**, relative to `#{base_url}`. Every `/api/v4` endpoint needs a bearer key; `/rescue` and `/<id>/<filename>` are public.

        - `POST /api/v4/upload` — upload one file (`multipart/form-data`, field `file`). Returns `201` and the upload object.
        - `POST /api/v4/uploads` — upload up to #{BatchUploadService::MAX_FILES_PER_BATCH} files (field `files[]`). Returns `201` with `uploads` and `failed` arrays; partial success is normal.
        - `POST /api/v4/upload_from_url` — mirror a file from a URL (`{"url": "..."}`).
        - `PATCH /api/v4/uploads/:id/rename` — rename an upload (`{"filename": "..."}`). Changes the public URL.
        - `DELETE /api/v4/upload/:id` — delete one upload.
        - `DELETE /api/v4/uploads/batch` — delete several (`{"ids": ["..."]}`). Unknown IDs come back in `not_found`.
        - `GET /api/v4/me` — the key's owner, storage used, storage limit, and quota tier.
        - `POST /api/v4/revoke` — revoke the key making the request. Irreversible; uploads are untouched.
        - `GET /rescue?url=<original url>` — find where a file from an older Hack Club CDN moved to. Redirects on a hit, `404` on a miss.
        - `GET /<id>/<filename>` — public file delivery. Redirects to storage; safe to hotlink.
      MARKDOWN
    end

    def limits
      rows = Quota::ALL_POLICIES.values.map do |policy|
        "- #{policy.slug.to_s.humanize}: #{human_size(policy.max_file_size)} per file, #{human_size(policy.max_total_storage)} total."
      end

      <<~MARKDOWN
        **Limits.** Quotas are per user; the tier comes from the account's verification status with Hack Club.

        #{rows.join("\n")}

        New accounts start unverified, and verifying at #{AUTH_URL} raises the tier automatically. Exceeding a quota returns `402` with a `quota` object containing `storage_used`, `storage_limit`, `quota_tier`, and `percentage_used`. Check `GET /api/v4/me` before a large batch rather than discovering the limit mid-upload.
      MARKDOWN
    end

    def errors
      <<~MARKDOWN
        **Errors** are always JSON, including `404`s for unknown paths under `/api` and any request sent with `Accept: application/json`. The shape is stable:

        ```json
        {
          "error": "Missing file parameter",
          "code": "missing_parameter",
          "message": "Required parameter `file` is missing or blank.",
          "hint": "Send the file as multipart/form-data under the `file` field, e.g. `curl -F \\"file=@photo.jpg\\"`.",
          "status": 400,
          "documentation_url": "#{base_url}/docs/api"
        }
        ```

        Branch on `code` and treat `error` as legacy prose. The full enum lives in the OpenAPI document; the common codes are `invalid_auth` (401), `missing_parameter` and `too_many_files` (400), `quota_exceeded` and `file_too_large` (402), `not_found` and `upload_not_found` (404), `validation_failed` and `upload_failed` (422), and `internal_error` (500).
      MARKDOWN
    end

    def when_to_use
      <<~MARKDOWN
        ## When to use this

        - [Give a file a permanent public URL](#{base_url}/docs/api): the core job. You generated or were handed an image, PDF, video, data file, or archive and something else needs to link to it. `POST /api/v4/upload` with the file under the field `file`, then use the `url` from the response.
        - [Host images for a README, project page, or Slack message](#{base_url}/docs/using-cdn-urls): CDN URLs are stable and hotlink-friendly, which local paths and expiring share links are not.
        - [Mirror a file whose current URL will rot](#{base_url}/docs/api): a temporary object-storage link, a scraped asset, another platform's file host. `POST /api/v4/upload_from_url` copies it server-side, so you never move the bytes yourself.
        - [Upload a batch of files in one request](#{base_url}/docs/api): `POST /api/v4/uploads` takes up to #{BatchUploadService::MAX_FILES_PER_BATCH} files and reports per-file success, which is cheaper and kinder than a loop of single uploads.
        - [Recover a broken link from an older Hack Club CDN](#{base_url}/docs/using-cdn-urls): `GET /rescue?url=<original url>` redirects to the file's current home if it was migrated.
        - [Check how much room the user has left](#{base_url}/docs/quotas): `GET /api/v4/me` returns `storage_used`, `storage_limit`, and `quota_tier` in bytes. Do this before uploading something large.
        - [Rename or delete files the user uploaded here](#{base_url}/docs/api): `PATCH /api/v4/uploads/:id/rename`, `DELETE /api/v4/upload/:id`, and `DELETE /api/v4/uploads/batch`, using the IDs from earlier upload responses.
      MARKDOWN
    end

    def api
      <<~MARKDOWN
        ## API

        - [OpenAPI #{OpenAPISpec::SPEC_VERSION} description (JSON)](#{base_url}/openapi.json): every endpoint, request body, response schema, and error code, machine-readable and unauthenticated. Start here.
        - [API reference](#{base_url}/docs/api): the same surface as prose, with curl and JavaScript examples.
        - [Create an API key](#{base_url}/api_keys): where the user (not the agent) generates the `sk_cdn_...` token. Requires a Hack Club Auth session.
      MARKDOWN
    end

    def docs
      links = DocPage.all.map do |doc|
        "- [#{doc.title}](#{base_url}#{doc.path})#{doc.summary.present? ? ": #{doc.summary}" : ''}"
      end

      <<~MARKDOWN
        ## Docs

        #{links.join("\n")}
      MARKDOWN
    end

    def optional
      <<~MARKDOWN
        ## Optional

        - [OpenAPI description (YAML)](#{base_url}/openapi.yaml): the same document as `/openapi.json`, in YAML.
        - [Sitemap](#{base_url}/sitemap.xml): every indexable page on this site, with last-modified dates.
        - [Source code](#{GITHUB_URL}): the Rails application behind this service, including its issue tracker.
        - [#cdn-dev on Hack Club Slack](#{SLACK_URL}): where to ask a human about this service.
        - [Hack Club](#{HACK_CLUB_URL}): the nonprofit that runs the CDN.
      MARKDOWN
    end

    def human_size(bytes) = ActiveSupport::NumberHelper.number_to_human_size(bytes)
  end
end
