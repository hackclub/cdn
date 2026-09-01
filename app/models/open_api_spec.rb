# frozen_string_literal: true

class OpenAPISpec
  SPEC_VERSION = "3.2.0"
  API_VERSION = "4.0.0"

  class << self
    def host = ENV["CDN_HOST"].presence || "cdn.hackclub.com"

    def base_url = "https://#{host}"

    def as_json(*) = document

    def to_json(*) = JSON.pretty_generate(document)

    def to_yaml = document.deep_stringify_keys.to_yaml

    def document
      {
        openapi: SPEC_VERSION,
        info: info,
        externalDocs: {
          description: "Hack Club CDN documentation",
          url: "#{base_url}/docs"
        },
        servers: [ { url: base_url, description: "Production" } ],
        security: [ { bearerAuth: [] } ],
        tags: tags,
        paths: paths,
        components: components
      }
    end

    private

    def info
      {
        title: "Hack Club CDN API",
        summary: "Upload, rename and delete files on the Hack Club CDN.",
        description: <<~MARKDOWN,
          File hosting for Hack Clubbers. Upload a file and get back a permanent
          `https://#{host}/<id>/<filename>` URL.

          Authenticate every `/api/v4` request with an API key created at
          #{base_url}/api_keys, sent as `Authorization: Bearer sk_cdn_...`.

          Errors are always JSON with a stable machine-readable `code`, a
          human-readable `message` and a `hint` describing how to fix it.
          Storage is quota-limited per user; exceeding a quota returns
          `402 Payment Required` with a `quota` object.
        MARKDOWN
        version: API_VERSION,
        termsOfService: "#{base_url}/docs/terms",
        contact: {
          name: "Hack Club CDN maintainers",
          url: "https://github.com/hackclub/cdn/issues"
        }
      }
    end

    def tags
      [
        { name: "Uploads", description: "Create, rename and delete files." },
        { name: "Account", description: "Authenticated user and quota information." },
        { name: "API keys", description: "Manage the key making the request." },
        { name: "Files", description: "Public, unauthenticated file delivery." }
      ]
    end

    def paths
      {
        "/api/v4/me": {
          get: {
            operationId: "getCurrentUser",
            tags: [ "Account" ],
            summary: "Get the authenticated user and quota usage",
            description: "Returns the owner of the API key making the request, plus current storage usage and limits in bytes.",
            responses: {
              "200": json_response("The authenticated user.", "#/components/schemas/User"),
              "401": error_response(:unauthorized)
            }
          }
        },
        "/api/v4/upload": {
          post: {
            operationId: "createUpload",
            tags: [ "Uploads" ],
            summary: "Upload a single file",
            description: "Uploads one file as multipart/form-data and returns its permanent CDN URL.",
            requestBody: {
              required: true,
              content: {
                "multipart/form-data": {
                  schema: {
                    type: "object",
                    required: [ "file" ],
                    properties: {
                      file: { type: "string", format: "binary", description: "The file to upload." }
                    }
                  }
                }
              }
            },
            responses: {
              "201": json_response("The stored upload.", "#/components/schemas/Upload"),
              "400": error_response(:bad_request),
              "401": error_response(:unauthorized),
              "402": error_response(:payment_required),
              "422": error_response(:unprocessable_entity)
            }
          }
        },
        "/api/v4/uploads": {
          post: {
            operationId: "createUploadsBatch",
            tags: [ "Uploads" ],
            summary: "Upload up to 40 files in one request",
            description: "Uploads several files as multipart/form-data. Partial success is normal: successful files are listed in `uploads`, rejected ones in `failed`. Returns 201 when at least one file succeeded, otherwise 422.",
            requestBody: {
              required: true,
              content: {
                "multipart/form-data": {
                  schema: {
                    type: "object",
                    required: [ "files" ],
                    properties: {
                      files: {
                        type: "array",
                        maxItems: BatchUploadService::MAX_FILES_PER_BATCH,
                        description: "Repeated `files[]` fields, at most #{BatchUploadService::MAX_FILES_PER_BATCH} per request.",
                        items: { type: "string", format: "binary" }
                      }
                    }
                  }
                }
              }
            },
            responses: {
              "201": json_response("At least one file was stored.", "#/components/schemas/BatchUploadResult"),
              "400": error_response(:bad_request),
              "401": error_response(:unauthorized),
              "422": json_response("No file could be stored.", "#/components/schemas/BatchUploadResult")
            }
          }
        },
        "/api/v4/upload_from_url": {
          post: {
            operationId: "createUploadFromUrl",
            tags: [ "Uploads" ],
            summary: "Upload a file by fetching a URL",
            description: "Downloads the given URL server-side and stores it. The source URL must be publicly reachable, or supply credentials with the `X-Download-Authorization` header.",
            parameters: [
              {
                name: "X-Download-Authorization",
                in: "header",
                required: false,
                description: "Sent as the `Authorization` header when fetching the source URL.",
                schema: { type: "string" }
              }
            ],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    required: [ "url" ],
                    properties: {
                      url: { type: "string", format: "uri", description: "Publicly reachable URL of the file to store." }
                    }
                  }
                }
              }
            },
            responses: {
              "201": json_response("The stored upload.", "#/components/schemas/Upload"),
              "400": error_response(:bad_request),
              "401": error_response(:unauthorized),
              "402": error_response(:payment_required),
              "422": error_response(:unprocessable_entity)
            }
          }
        },
        "/api/v4/uploads/{id}/rename": {
          patch: {
            operationId: "renameUpload",
            tags: [ "Uploads" ],
            summary: "Rename an upload",
            description: "Changes the filename segment of the CDN URL. The old URL stops resolving, so update any references.",
            parameters: [ upload_id_parameter ],
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    required: [ "filename" ],
                    properties: {
                      filename: { type: "string", description: "New filename, including extension." }
                    }
                  }
                }
              }
            },
            responses: {
              "200": json_response("The renamed upload.", "#/components/schemas/Upload"),
              "400": error_response(:bad_request),
              "401": error_response(:unauthorized),
              "404": error_response(:not_found),
              "422": error_response(:unprocessable_entity)
            }
          }
        },
        "/api/v4/upload/{id}": {
          delete: {
            operationId: "deleteUpload",
            tags: [ "Uploads" ],
            summary: "Delete an upload",
            description: "Permanently deletes the file and frees the storage it used. Only the key owner's uploads are visible.",
            parameters: [ upload_id_parameter ],
            responses: {
              "200": json_response("The upload was deleted.", "#/components/schemas/DeletedUpload"),
              "401": error_response(:unauthorized),
              "404": error_response(:not_found)
            }
          }
        },
        "/api/v4/uploads/batch": {
          delete: {
            operationId: "deleteUploadsBatch",
            tags: [ "Uploads" ],
            summary: "Delete several uploads",
            description: "Deletes many uploads at once. IDs that do not belong to the key owner are reported in `not_found` rather than failing the request.",
            requestBody: {
              required: true,
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    required: [ "ids" ],
                    properties: {
                      ids: {
                        type: "array",
                        minItems: 1,
                        items: { type: "string", format: "uuid" },
                        description: "Upload IDs to delete."
                      }
                    }
                  }
                }
              }
            },
            responses: {
              "200": json_response("Deletion results.", "#/components/schemas/BatchDeleteResult"),
              "400": error_response(:bad_request),
              "401": error_response(:unauthorized)
            }
          }
        },
        "/api/v4/revoke": {
          post: {
            operationId: "revokeCurrentApiKey",
            tags: [ "API keys" ],
            summary: "Revoke the API key making the request",
            description: "Immediately and irreversibly revokes the key used to authenticate this request. Uploads are not deleted.",
            responses: {
              "200": json_response("The key was revoked.", "#/components/schemas/RevokedKey"),
              "401": error_response(:unauthorized)
            }
          }
        },
        "/{id}/{filename}": {
          get: {
            operationId: "getFile",
            tags: [ "Files" ],
            summary: "Fetch an uploaded file",
            description: "Public, unauthenticated file delivery. Redirects to the storage host with a one-year cache lifetime. CORS is open to all origins.",
            security: [],
            parameters: [
              upload_id_parameter,
              {
                name: "filename",
                in: "path",
                required: true,
                description: "Filename of the upload.",
                schema: { type: "string" }
              }
            ],
            responses: {
              "302": {
                description: "Redirect to the file on the storage host.",
                headers: {
                  Location: { description: "Absolute URL of the file.", schema: { type: "string", format: "uri" } }
                }
              },
              "404": { description: "No upload with that ID exists." }
            }
          }
        },
        "/rescue": {
          get: {
            operationId: "rescueByOriginalUrl",
            tags: [ "Files" ],
            summary: "Look up a file by the URL it was imported from",
            description: "Finds a file previously imported with `upload_from_url` and redirects to its CDN URL. Used to repair links to retired hosts.",
            security: [],
            parameters: [
              {
                name: "url",
                in: "query",
                required: true,
                description: "The original URL the file was imported from.",
                schema: { type: "string", format: "uri" }
              }
            ],
            responses: {
              "302": {
                description: "Redirect to the CDN URL of the matching file.",
                headers: {
                  Location: { description: "CDN URL of the file.", schema: { type: "string", format: "uri" } }
                }
              },
              "400": {
                description: "The `url` parameter is missing.",
                content: { "application/json": { schema: { "$ref": "#/components/schemas/Error" } } }
              },
              "404": {
                description: "No file was imported from that URL. Image requests receive a placeholder SVG instead of a JSON body.",
                content: {
                  "application/json": { schema: { "$ref": "#/components/schemas/Error" } },
                  "image/svg+xml": { schema: { type: "string" } }
                }
              }
            }
          }
        }
      }
    end

    def upload_id_parameter
      {
        name: "id",
        in: "path",
        required: true,
        description: "Upload ID returned when the file was created.",
        schema: { type: "string", format: "uuid" }
      }
    end

    def json_response(description, schema_ref)
      {
        description: description,
        content: { "application/json": { schema: { "$ref": schema_ref } } }
      }
    end

    ERROR_RESPONSES = {
      bad_request: [ "A required parameter is missing or malformed.", "#/components/schemas/Error" ],
      unauthorized: [ "The API key is missing, invalid or revoked.", "#/components/schemas/Error" ],
      payment_required: [ "The upload would exceed the account's storage quota.", "#/components/schemas/QuotaError" ],
      not_found: [ "No matching resource belongs to the API key's owner.", "#/components/schemas/Error" ],
      unprocessable_entity: [ "The request was understood but the file could not be stored.", "#/components/schemas/Error" ]
    }.freeze

    def error_response(kind)
      description, schema_ref = ERROR_RESPONSES.fetch(kind)
      json_response(description, schema_ref)
    end

    def components
      {
        securitySchemes: {
          bearerAuth: {
            type: "http",
            scheme: "bearer",
            description: "API key created at #{base_url}/api_keys, sent as `Authorization: Bearer sk_cdn_...`."
          }
        },
        schemas: {
          Upload: {
            type: "object",
            description: "A stored file.",
            required: [ "id", "filename", "size", "content_type", "url", "created_at" ],
            properties: {
              id: { type: "string", format: "uuid", description: "Upload ID." },
              filename: { type: "string", description: "Filename as stored." },
              size: { type: "integer", description: "Size in bytes." },
              content_type: { type: "string", description: "Detected MIME type." },
              url: { type: "string", format: "uri", description: "Permanent public CDN URL." },
              created_at: { type: "string", format: "date-time", description: "ISO 8601 creation time." }
            }
          },
          DeletedUpload: {
            type: "object",
            required: [ "id", "deleted" ],
            properties: {
              id: { type: "string", format: "uuid" },
              deleted: { type: "boolean", const: true }
            }
          },
          BatchUploadResult: {
            type: "object",
            required: [ "uploads", "failed" ],
            properties: {
              uploads: { type: "array", items: { "$ref": "#/components/schemas/Upload" }, description: "Files that were stored." },
              failed: {
                type: "array",
                description: "Files that were rejected.",
                items: {
                  type: "object",
                  required: [ "filename", "reason" ],
                  properties: {
                    filename: { type: "string" },
                    reason: { type: "string", description: "Why this file was rejected." }
                  }
                }
              }
            }
          },
          BatchDeleteResult: {
            type: "object",
            required: [ "deleted" ],
            properties: {
              deleted: {
                type: "array",
                items: {
                  type: "object",
                  required: [ "id", "filename" ],
                  properties: {
                    id: { type: "string", format: "uuid" },
                    filename: { type: "string" }
                  }
                }
              },
              not_found: {
                type: "array",
                items: { type: "string", format: "uuid" },
                description: "IDs that did not match an upload owned by the key owner. Omitted when every ID matched."
              }
            }
          },
          User: {
            type: "object",
            required: [ "id", "email", "name", "storage_used", "storage_limit", "quota_tier" ],
            properties: {
              id: { type: "string", description: "Public user ID." },
              email: { type: "string", format: "email" },
              name: { type: "string" },
              storage_used: { type: "integer", description: "Bytes currently stored." },
              storage_limit: { type: "integer", description: "Bytes allowed." },
              quota_tier: { "$ref": "#/components/schemas/QuotaTier" }
            }
          },
          QuotaTier: {
            type: "string",
            description: "Storage tier of the account.",
            enum: Quota::ALL_POLICIES.keys.map(&:to_s)
          },
          RevokedKey: {
            type: "object",
            required: [ "success", "owner_email", "key_name", "status" ],
            properties: {
              success: { type: "boolean", const: true },
              owner_email: { type: "string", format: "email" },
              key_name: { type: "string" },
              status: { type: "string", const: "complete" }
            }
          },
          Error: {
            type: "object",
            description: "Every error response uses this shape. Branch on `code`, show `message`, act on `hint`.",
            required: [ "error", "code", "message", "status", "documentation_url" ],
            properties: {
              error: { type: "string", description: "Short error string. Kept for backwards compatibility; prefer `code`." },
              code: {
                type: "string",
                description: "Stable machine-readable error code.",
                enum: %w[
                  invalid_auth
                  missing_parameter
                  too_many_files
                  quota_exceeded
                  file_too_large
                  upload_failed
                  rename_failed
                  upload_not_found
                  not_found
                  route_not_found
                  original_url_not_found
                  validation_failed
                  internal_error
                ]
              },
              message: { type: "string", description: "Human-readable description of what went wrong." },
              hint: { type: "string", description: "How to resolve the error." },
              status: { type: "integer", description: "HTTP status code, repeated for clients that only read the body." },
              documentation_url: { type: "string", format: "uri", description: "Documentation for this API." },
              details: { type: "array", items: { type: "string" }, description: "Field-level validation messages, when applicable." },
              parameter: { type: "string", description: "Name of the offending parameter, when applicable." },
              error_id: { type: "string", description: "Support identifier for server errors." }
            }
          },
          QuotaError: {
            allOf: [
              { "$ref": "#/components/schemas/Error" },
              {
                type: "object",
                required: [ "quota" ],
                properties: {
                  quota: {
                    type: "object",
                    required: [ "storage_used", "storage_limit", "quota_tier", "percentage_used" ],
                    properties: {
                      storage_used: { type: "integer", description: "Bytes currently stored." },
                      storage_limit: { type: "integer", description: "Bytes allowed." },
                      quota_tier: { "$ref": "#/components/schemas/QuotaTier" },
                      percentage_used: { type: "number", description: "Percentage of the limit in use." }
                    }
                  }
                }
              }
            ]
          }
        }
      }
    end
  end
end
