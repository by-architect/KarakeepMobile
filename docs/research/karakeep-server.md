# Karakeep server — research notes for the mobile client

Source: `karakeep-app/karakeep` @ `3c44114` (2026-09-22), cloned to
`../../referanced-repos/karakeep` (paths below are relative to that repo).
Server docs: v0.33.x. Official mobile app: Expo, v1.11.2 (`apps/mobile`).

## 1. Licensing & naming

- Server is **AGPL-3.0**, owned by Localhost Labs Ltd. A client that only talks
  to the API is not bound by it; copying their code/assets would be.
- No trademark policy in the repo. Use our **own app name and logo** and describe
  the app as "a client for Karakeep", not "Karakeep".

## 2. Which API to use

| Surface | Path | Use it for |
|---|---|---|
| REST v1 | `/api/v1/*` | **Everything we can** — stable, OpenAPI-described |
| tRPC | `/api/trpc/<router.proc>` | Only what REST lacks: login exchange, client config, (later) rules/webhooks/prompts |
| Misc | `/api/health`, `/api/version`, `/api/assets/*`, `/api/public/assets/*` | Connection test, version, asset bytes |

- OpenAPI 3.0 spec: `packages/open-api/karakeep-openapi-spec.json`
  (raw: `https://raw.githubusercontent.com/karakeep-app/karakeep/refs/heads/main/packages/open-api/karakeep-openapi-spec.json`).
  Candidate for Dart client generation. Its `bearerFormat: JWT` is wrong — keys are opaque.
- REST handlers are thin wrappers over tRPC (`packages/api/routes/*.ts`); shared
  zod types in `packages/shared/types/*.ts` are the source of truth.
- The official app uses tRPC for almost everything. The server itself calls the
  tRPC-as-API approach a stopgap, so we prefer REST.

### tRPC wire format (superjson, non-batched)

```
POST {server}/api/trpc/apiKeys.exchange
{"json": {"email": "...", "password": "...", "keyName": "..."}}
-> {"result": {"data": {"json": {...}, "meta": {...}}}}
-> {"error":  {"json": {"message", "code", "data": {"code": "UNAUTHORIZED", "httpStatus": 401}}}}

GET {server}/api/trpc/config.clientConfig   (query; input via ?input=<urlencoded json>)
```

## 3. Server setup & authentication

### What the user enters
1. **Server URL** (self-hosted or `https://cloud.karakeep.app`). Normalise: trim,
   require `http(s)://`, strip trailing `/`.
2. **Optional custom headers** (key/value) — for Cloudflare Access, Authelia,
   reverse proxies. Sent on *every* request, including image loads.
3. **Credentials**, one of:
   - **Email + password** → tRPC `apiKeys.exchange` (public) →
     `{id, name, key, createdAt, scopes}`. Store `key` + `id`.
     Errors: `UNAUTHORIZED` (wrong creds), `FORBIDDEN` (password auth disabled /
     email unverified). Rate-limited 10 per 15 min.
   - **Paste API key** (needed for SSO-only users) → validate with
     `GET /api/v1/users/me` (or tRPC `apiKeys.validate`).

### Before sign-in (server validation)
- `GET /api/health` → `{"status":"ok"}` (no auth) — reachability.
- `GET /api/version` → `{"version"}` — feature-detect by version.
- tRPC `config.clientConfig` → `auth.disablePasswordAuth`, `auth.disableSignups`,
  `inference.*`, `search.semanticSearchEnabled`, `demoMode`, `serverVersion`, …
  If `disablePasswordAuth` → show only the "paste API key" path.
- `GET /.well-known/api-catalog` — RFC 9727 linkset (nice-to-have).

### Requests
- `Authorization: Bearer ak2_<keyId>_<secret>` (legacy `ak1_`).
- Keys have scopes (`fullaccess` or `<resource>:read|readwrite`); missing scope → 403.
- **SSO/OIDC**: web-only (NextAuth, generic `custom` provider). No mobile flow
  exists; users create a key in web Settings → API Keys and paste it.
- **Logout**: `apiKeys.revoke` is a `sessionProcedure` which rejects API-key auth
  (`packages/trpc/index.ts:202`), so a client *cannot* revoke its own key —
  the official app's call silently fails. We clear locally and tell the user
  where to revoke on the web.
- Self-signed/homelab TLS: official app allows cleartext + user-installed CAs on
  Android and arbitrary loads on iOS. We need the same (opt-in per server ideally).

## 4. REST endpoints (`/api/v1`)

Conventions: query booleans are the strings `"true"`/`"false"`. Cursor
pagination (`nextCursor` → `?cursor=`), `limit` 1–100, default 20. Search
cursor is an offset string — treat all cursors as opaque. Errors may be
text/plain (`HTTPException`), JSON `{code,message}`, or zod JSON (400).
Demo/read-only mode → 403 on mutations. Rate limiting (if enabled) → 429.

### Bookmarks
| Method | Path | Notes |
|---|---|---|
| GET | `/bookmarks` | `archived`, `favourited`, `sortOrder`, `limit`, `cursor`, `includeContent` |
| POST | `/bookmarks` | `{type:"link",url}` / `{type:"text",text,sourceUrl?}` / `{type:"asset",assetType:image\|pdf,assetId}` + `title,note,archived,favourited,source,crawlPriority`. 201 new, 200 + `alreadyExists` |
| GET | `/bookmarks/search` | `q` (query language), `searchMode=fts\|semantic\|hybrid`, `sortOrder=relevance\|asc\|desc` |
| GET | `/bookmarks/check-url` | `url` → `{bookmarkId\|null}` (dedupe before saving) |
| GET/PATCH/DELETE | `/bookmarks/{id}` | PATCH: archived, favourited, title, note, summary, url, description, author, publisher, dates, text |
| GET | `/bookmarks/{id}/content` | `format=markdown\|text`, `maxChars`, `cursor`; ETag; 409 if content changed mid-paging |
| POST | `/bookmarks/{id}/summarize` | trigger AI summary |
| POST/DELETE | `/bookmarks/{id}/tags` | `{tags:[{tagId\|tagName, attachedBy?}]}` |
| GET | `/bookmarks/{id}/lists`, `/highlights`, `/assets` | |
| POST/PUT/DELETE | `/bookmarks/{id}/assets[/{assetId}]` | attach / replace / detach |

### Lists
`GET/POST /lists` (not paginated; POST needs `name`, `icon` emoji, `type`
manual|smart, `query` for smart, `parentId?`), `GET/PATCH/DELETE /lists/{id}`
(PATCH also toggles `public`), `GET /lists/{id}/bookmarks`,
`PUT/DELETE /lists/{id}/bookmarks/{bookmarkId}`.
List: `{id,name,description,icon,parentId,type,query,public,hasCollaborators,userRole}`.

### Tags
`GET /tags` (`nameContains`, `sort=name|usage|relevance`, `attachedBy`,
paginated), `POST /tags`, `GET/PATCH/DELETE /tags/{id}`, `GET /tags/{id}/bookmarks`.
Tag: `{id,name,numBookmarks,numBookmarksByAttachedType:{ai,human}}`.

### Highlights
`GET/POST /highlights`, `GET/PATCH/DELETE /highlights/{id}`.
`{bookmarkId,startOffset,endOffset,color:yellow|red|green|blue,text,note}`.

### Users
`GET /users/me` → `{id,name,email,image,localUser}`;
`GET /users/me/stats` → counts, top domains, activity by hour/day, tag usage, sources.

### Assets
- Upload: `POST /assets`, multipart field **`file`** → `{assetId,contentType,size,fileName}`.
  jpeg/png/gif/webp/pdf (+ video/html for other uses). Limit `MAX_ASSET_SIZE_MB`
  (default 50) → 413. Then create `{type:"asset"}` bookmark.
- Fetch: `GET /api/assets/{id}` with Bearer + custom headers. Range supported,
  immutable cache headers → cache by id.
- Header-less contexts (WebView, video, share): `GET /assets/{id}/signed-url` →
  `GET /api/public/assets/{id}?token=…` (~1h).

### Feeds (RSS subscriptions)
`GET/POST /feeds`, `GET/PATCH/DELETE /feeds/{id}`, `POST /feeds/{id}/fetch`.
`{name,url,enabled,importTags,lastFetchedStatus,lastFetchedAt,…}`.

### Backups
`GET/POST /backups`, `GET/DELETE /backups/{id}`, `GET /backups/{id}/download`.

### Admin (admin users only)
`PUT /admin/users/{userId}`, `POST /admin/jobs/trigger/{recrawl|reindex|inference}`.

### tRPC-only
Rules engine, AI prompts, user webhooks, import sessions, invites, API key
management, list collaborators/invitations, public lists, reading progress,
user settings (reader prefs, AI prefs, backup schedule).

## 5. Bookmark model

- Top level: `id, createdAt` (= *last saved*), `firstCreatedAt, modifiedAt, title,
  archived, favourited, note, summary, source, userId,
  taggingStatus/summarizationStatus/embeddingStatus` (success|failure|pending|null),
  `tags[{id,name,attachedBy}]`, `assets[{id,assetType,fileName}]`.
- `content` union on `type`:
  - **link**: `url, title, description, imageUrl, favicon, author, publisher,
    datePublished, dateModified, crawledAt, crawlStatus, readerViewStatus,
    readerViewScore, preferredPreview`, asset ids (`imageAssetId,
    screenshotAssetId, pdfAssetId, fullPageArchiveAssetId, videoAssetId,
    contentAssetId`), `htmlContent` (only with `includeContent`).
  - **text**: `text, sourceUrl`.
  - **asset**: `assetType image|pdf, assetId, fileName, sourceUrl, size, content`.
  - **unknown**: parse defensively.
- Display title: `title ?? content.title ?? url`.
- Poll while `crawlStatus`/`taggingStatus` is `pending`.

## 6. Search query language

Parser `packages/shared/searchQueryParser.ts`; docs
`docs/docs/04-using-karakeep/search-query-language.md`. Used by search and smart lists.

`is:fav|archived|tagged|inlist|link|text|media|broken`, `url:`, `title:`,
`#tag`/`tag:`, `list:`, `feed:`, `source:`, `after:YYYY-MM-DD`, `before:`,
`age:<1d` (d|w|m|y). Implicit AND, `and`/`or`, parentheses, `-`/`!` negation,
quoted values. Remaining text = full-text. Gate semantic/hybrid on
`clientConfig.search.semanticSearchEnabled`.

## 7. Official mobile app — baseline to beat

Has: server URL + custom headers, test-connection diagnostics, password or
API-key login, home/favourites/archive, lists (manual + smart, nested, emoji),
tags CRUD, highlights tab, search (fts/hybrid/semantic + history), reader view
with highlights + reading progress + reader settings, in-app browser /
screenshot / archive / PDF views, notes, AI summary, share intent (single item,
saves instantly), photo-library upload, 7-day read cache, manual offline
library, stats, theme, configurable toolbar.

Gaps we can fill:
- SSO/OIDC-friendly login (guided API-key flow, QR scan of key)
- multiple servers/accounts
- offline mutation queue (it fails mutations when offline)
- share sheet with tags/lists/note before saving; multi-file share
- camera capture / document scan
- bulk select & bulk actions
- RSS feed management (REST exists)
- backups create/download (REST exists)
- list sharing/collaborators, rules, webhooks, AI prompts, import (tRPC)
- asset/broken-link management, admin screens
- home-screen widgets, quick-save tile, search-syntax builder, stats charts

## 8. Server-side feature inventory (for later phases)

AI tagging/summaries (OpenAI/Ollama, custom prompts, tag style/language),
OCR, full-page archive (monolith), video download (yt-dlp), PDF capture,
SingleFile, reader mode, highlights, manual/smart/nested/public lists, list
collaboration (viewer/editor), RSS in (feeds) and out (per-list RSS token),
rule engine (triggers: bookmarkAdded, tagAdded/Removed, addedTo/removedFromList,
favourited, archived; actions: add/remove tag/list, archive, favourite, full
archive), webhooks, import (Netscape HTML, Pocket, Matter, Omnivore, Karakeep,
Linkwarden, Instapaper, Readwise, mymind, OneTab, Tab Session Manager),
export (Karakeep JSON, Netscape HTML), scheduled backups, quotas, admin.
