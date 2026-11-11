---
name: scryer
description: Full native Scryer administration for Simon, Laure, and Household. Use for movies and TV/anime, subscribing to or following named shows, exact season, episode or future-only scopes, acquisition and download queues, imports, progress, libraries, configuration, providers, users, security, backups, restore, plugins, lists, logs, and any other Scryer app action.
---

# Scryer

Scryer has one native GraphQL API. Simon, Laure and Household are all trusted admins. Learn the API from the live schema, not from memory.

## Send a request
Use the `scryer_graphql` MCP tool. It logs in as `admin` with the sops-nix password credential, caches the session, and returns the JSON reply. Put user values in `variables`; never paste them into the query text.
```json
{"query":"query($q:String!){titles(query:$q,limit:10){items{id name facet monitored monitorType}}}","variables":{"q":"Dune"}}
```
A reply can hold `data` and `errors` together. Always read `.errors[].message` and `.errors[].extensions.code`. Common codes: `VALIDATION_ERROR`, `NOT_FOUND`, `UNAUTHORIZED`, `RATE_LIMITED`, `MFA_STEP_UP_REQUIRED` (HTTP 460), `TEMPORARY_UNAVAILABLE` (see `retryAfterSeconds`). HTTP-level failures return a structured error with `kind`, `status`, and the JSON `body` when available. If `scryer_graphql` itself fails to log in, report its message; do not create another account, key or password.

## Show cards
Two tools draw interactive cards in the chat. Prefer them when the person wants to find, compare or look at media:
- `scryer_search {query}`: search results as tiles, with library state and **Add** / **Monitor** buttons. Use it to tell same-named titles apart (remakes, US and UK versions).
- `scryer_title {titleId}`: one library title with its seasons, what is monitored and what is on disk, with **Monitor** / **Unmonitor** per season and per episode. `titleId` is Scryer's title id (from `scryer_search` results or `titles`).

You do not see the card, and you do not see what the person presses. Each button changes Scryer at an exact scope and then re-reads it; the card shows only what Scryer reports. If the person says they pressed something, read the state again with `scryer_graphql` before you describe it. The cards never delete or restore; those stay in chat under the rules below. Both tools return the same data as JSON, so you can answer from it too.

## Discover the schema
Introspection is on. The root types are `QueryRoot`, `MutationRoot` and `SubscriptionRoot`. Read the descriptions: they say what omission, `null` and empty values do.
Call `scryer_graphql` with these arguments to find monitoring mutations:
```json
{"query":"{__schema{mutationType{fields{name}}}}"}
```
To inspect an input object, enum or type:
```json
{"query":"query($n:String!){__type(name:$n){kind description fields{name description args{name description defaultValue type{...R}} type{...R}} inputFields{name description defaultValue type{...R}} enumValues{name description}}} fragment R on __Type{kind name ofType{kind name ofType{kind name ofType{kind name}}}}","variables":{"n":"AddTitleInput"}}
```
Use the same query with `variables: {"n":"MutationRoot"}` and read the `addTitle` field to find that root field and its arguments.
Unwrap `type` through `ofType`: `NON_NULL` means required, `LIST` means a list.

## Work safely
- Identify the exact media first. If a name matches more than one title (remakes, US and UK versions, same name in different years), ask which one before adding anything, unless the user's words already decide it.
- Read the current state before every change. Find titles with `titles(query:)`, `title(id:)` or `titlesByExternalIds`. Use `searchMetadata` only to add a new title; its `existingTitleId` is not reliable. Change an existing title; do not add it again. After `addTitle`, check `reusedExistingTitle`.
- Keep the exact scope the user asked for. Never widen it to the whole show without asking.
  - Whole show: `monitorType: ALL_EPISODES`. Future episodes only: `FUTURE_EPISODES`. Missing and future: `MISSING_AND_FUTURE_EPISODES`.
  - Named seasons: `monitorType: ADVANCED` with `options.monitorSelection.seasonNumbers` (0 is specials). Other seasons, and seasons that appear later, stay unmonitored.
  - Named episodes: use `setEpisodeMonitored` per episode. For a new show, add it with `monitorType: NONE` and wait until `metadataHydrationState` is not `PENDING` and episodes exist, then mark only those episodes.
- Patch only the fields the user named. Omitted input fields keep their value; `null` often clears. For settings, read the current object first and send back the other values unchanged.
- Destructive actions need confirmation first: deleting titles, files, backups, users, libraries, lists or plugins, emptying the recycle bin, restore, revoking access, and security changes that can lock users out. State the exact effect, including the number of files removed from disk. Run the matching `...Preview` query first when one exists (for example `deleteTitlePreview`) and pass its `fingerprint` as `previewFingerprint`, and its `typedConfirmationPrompt` as `typedConfirmation`. Ordinary explicit requests (add, monitor, search, pause, settings change) need no second approval.
- After every write, read the state again and report it. Say clearly what is done and what is still pending (hydration, searches, downloads, imports, jobs, restarts). Do not claim a download or import that has not happened.
- After a timeout or a network error, do not send the mutation again. Read the state first; the change may already be done.
- Some queries return stored secrets in plain text. Select secret fields only when the task needs them, and never repeat a secret in a reply.

## Uploads and other routes
Uploads and backup downloads are not available through `scryer_graphql`. This tool accepts only GraphQL JSON; it does not send multipart uploads, read local files, or fetch download URLs. Use Simon's own assistant for uploads, plugin file installation, restore bundles, and backup downloads. Do not request or expose a session token to work around this boundary.
