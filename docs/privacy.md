# Privacy hub endpoints

Hack Club's [privacy hub specification](https://yeet.hackclub.com/docs/deletions) governs these endpoints:

| Endpoint | Behavior |
| --- | --- |
| `POST /api/privacy/delete` | Deletes the subject's CDN data, or executes and rolls back that deletion for a dry run. |
| `POST /api/privacy/export` | Reports counts of held data. It does not deliver file contents or mutate account data. |

Send `Authorization: Bearer <token>` and `Accept: application/json`, with no request body. Middleware discards request bodies and query strings before Rails parses them. These controllers inherit `ActionController::API` and do not run browser authentication or Sentry user-context callbacks.

## Authentication and replay protection

The audience is exactly **`cdn`**. Ruby JWT verifies an ES256 signature using the header's `kid` and the hub's public keys at `https://yeet.hackclub.com/.well-known/jwks.json`. `PRIVACY_JWKS_URL` overrides that URL for local testing. Keys are cached in process for five minutes; unknown keys trigger refreshes no more than once every 30 seconds.

Tokens require `typ: JWT`, `iss: hackclub-privacy`, the exact audience string, integer `iat` and `exp`, a positive lifetime of at most 300 seconds, and 30 seconds of clock leeway. The action must match the endpoint. The verifier also validates `jti`, `request_id`, the boolean `dry_run`, and the subject's identifier types.

Each accepted `jti` is atomically inserted into `privacy_token_uses`. A uniqueness conflict returns `409 {"error":"replayed"}`; a database outage is a retriable failure. This is the only database write for export and the only durable write for a dry run. Replay records contain no subject identifiers and are pruned after one day by the production recurring job. Failed attempts consume their tokens too: the hub must retry with a fresh token.

## Matching

Match every `users` row whose email equals any `subject.emails` value case-insensitively, whose `slack_id` equals the signed Slack ID, or whose `hca_id` equals the signed `identity_id`. Null or absent Slack/identity identifiers match nothing. Multiple matching accounts are all included. No match returns `200` with `found: false` and zero counts.

## Deleted data

- `users`: email, name, Slack/HCA IDs, encrypted HCA access token, quota policy and account settings.
- `api_keys`: all personal API keys, including revoked keys and usage timestamps.
- `uploads`: ownership, provenance, original URLs and upload timestamps. Public upload links cease to resolve.
- `active_storage_attachments`, `active_storage_variant_records`, and exclusive `active_storage_blobs`: attachment references, filenames, file metadata, storage keys and tracked variant metadata.
- File contents in the blob's configured storage service (Cloudflare R2 in production, disk in development/tests), including tracked variant images and legacy untracked `variants/<blob-key>/` objects.
- Matching `solid_queue_jobs` payloads for Slack uploads and Cloudflare purges, plus their blocked, claimed, failed, ready, recurring and scheduled execution rows. Finished/failed Slack jobs are included because they retain Slack identifiers and file URLs.

Database deletions use one code path in a transaction, bypassing model callbacks that would delete files or enqueue jobs during a dry run. Reported database counts come from the actual deletion operations. Both primary and queue transactions roll back on a dry run. File removal and synchronous Cloudflare URL purging happen only on real deletion and before commit. Queue cleanup, when it uses a separate database, commits before the primary transaction. Cross-database and storage operations are not atomic: if a later operation fails, retries may find some external data already removed, but the primary account remains available for retry. Missing files can be deleted again safely.

Slack enqueue and processing share advisory locks with deletion. Running relevant jobs require manual review, and a worker holding an already-loaded job checks that its queue record still exists before processing. Matching pending Slack payloads are erased even if an account has not yet been created. File-creation paths lock the account row before writing to storage, so an upload racing deletion either finishes in time to be included or discovers the account is gone before writing a file. New Slack activity after deletion can create a new account; deletion is not a permanent signup ban.

## Kept data

| Data | Reason and treatment |
| --- | --- |
| Shared file blobs and their variants | Other accounts or surviving attachments use them. Remove the deleted account's upload/attachment references and report the shared blob count in `retained`. |
| `privacy_token_uses` | Replay protection; only `jti` and use time, pruned after one day. |
| Aggregate CDN statistics | No per-user identifiers or records; refresh normally within five minutes. |

There are no financial records, orders, ledger entries, account audit logs, version histories, server-side sessions or analytics tables in this application. The account row is deleted, so existing browser cookies no longer resolve to an account. Client-side cookies cannot be erased remotely. Queue infrastructure tables and the unused Solid Cable messages table have no user-specific application data.

## Manual review and operational requirements

- **Shared integration keys:** personal keys are deleted by default. Register numeric key IDs supporting shared integrations in `PRIVACY_SHARED_API_KEY_IDS` (comma-separated). An active registered key on a matching account returns `409 manual_review_required`; staff must resolve its ownership first.
- **Running jobs:** a matching claimed job or an active Slack-processing lock returns `409 manual_review_required` before database/file deletion. Stop or finish the work before submitting a fresh request.
- **Legacy migration copies:** the storage migration copied old keys from `hackclub-cdn/` and then replaced their database keys. Ownership of remaining old objects cannot reliably be reconstructed. Deletion of exclusive blobs refuses with `409 manual_review_required` while that prefix contains objects, or while a nonempty `tmp/old_storage_keys.txt` manifest exists. Complete the old-key cleanup and remove its manifest before retrying. Copies in other historical buckets require an operational inventory; the endpoint only knows the configured storage services.
- **Cloudflare:** production deletion requires `CLOUDFLARE_ZONE_ID` (the asset-host zone) and `CLOUDFLARE_API_TOKEN` with purge permission. Set `CLOUDFLARE_CDN_ZONE_ID` to the redirect-host zone when the hosts belong to different zones, as the default `hackclub-assets.com` and `hackclub.com` hosts do. Otherwise it defaults to the asset-host zone. The token needs purge permission for both zones. Purge both asset URLs and application redirect URLs. Missing configuration or a failed API response prevents a success response. Browser caches and copies downloaded by others cannot be recalled.
- **Backups:** the repository does not configure backup retention. Operators must inventory database/storage snapshots, establish expiry periods and reapply completed deletions before exposing a restored backup.

## External data outside this endpoint

- **Slack:** source files, source messages, bot replies and error messages remain in the workspace. The privacy hub's Slack target must handle them; CDN does not store a complete bot-message inventory.
- **Hack Club Auth:** the local access token and identity reference are removed. The upstream shared identity belongs to the hub's Auth target.
- **Sentry and logs:** historical events can contain user context (including email), job arguments, filenames, URLs and exception details. These require separate operational cleanup/retention; CDN has no subject-indexed deletion API for them. Privacy requests are silenced across the Rails request, SQL and storage logging path and excluded from Sentry events/transactions. Only the verified `request_id` and a fixed outcome are logged. Configure reverse-proxy/access logs to omit authorization headers and privacy endpoint query strings as well.

These external limitations are not presented as detached anonymous records: their contents are not anonymized by this endpoint, and reliable per-subject counts are unavailable.

## Responses and errors

Successful responses have exactly `request_id`, `found`, `dry_run`, `deleted` (record-type counts) and `retained` (objects with `type`, `count`, `reason`). Echo `request_id` and `dry_run` from the verified claims. Export uses the same count fields to inventory held data, without executing deletion. Responses contain no subject identifiers or file metadata.

Errors contain only `{"error":"snake_case_code"}`:

- `401 invalid_token`: malformed, expired, incorrectly signed or invalid claims/header.
- `400 action_mismatch`: action does not match the endpoint.
- `409 replayed` or `409 manual_review_required`.
- `503 jwks_unavailable`, `storage_unavailable`, `cache_unavailable` or `dependency_unavailable`: retry with a fresh token.

Deploy the migration before enabling the routes. Register the CDN API server's base URL and audience `cdn` with Hub staff. The hub's 15-second request timeout means large accounts may need staff coordination; storage/Cloudflare clients use short individual timeouts, but total deletion time grows with file count.
