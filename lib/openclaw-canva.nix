# Canva's official remote MCP server, the one exception to "every tool server
# is a front-door row" (lib/ai-mcp-rows.nix). It cannot be a row: the MCP SDK
# requires the OAuth protected-resource URL to match the server URL, so a
# proxied URL fails discovery, and the credential is each person's own Canva
# account, not a key the front door could hold. The gateway reaches it over its
# exit node like any public HTTPS host.
#
# Per-requester OAuth: the first Canva tool call returns a sign-in link to the
# person who asked; Canva then redirects to <gateway.publicOrigin>/oauth/mcp/callback.
# The client registers itself with Canva (dynamic client registration); no
# Developer Portal app or secret exists here.
{
  url = "https://mcp.canva.com/mcp";
  transport = "streamable-http";
  auth = "oauth";
  oauth.identity = "per-requester";
  # Design, asset, export, AI-image and editing tools. Left out: comments and
  # replies (they notify other people) and brand templates and autofill (paid).
  toolFilter.include = [
    "help"
    "resolve-shortlink"
    "search-designs"
    "get-design"
    "get-design-pages"
    "get-design-content"
    "get-design-thumbnail"
    "get-presenter-notes"
    "get-export-formats"
    "export-design"
    "generate-design"
    "create-design-from-candidate"
    "create-design"
    "get-create-design-async-job"
    "copy-design"
    "merge-designs"
    "import-design-from-url"
    "resize-design"
    "upload-asset-from-url"
    "create-upload-url"
    "get-assets"
    "generate-image"
    "get-generate-image-job"
    "remove-background"
    "separate-image-layers"
    "get-separate-image-layers-job"
    "start-editing-transaction"
    "perform-editing-operations"
    "commit-editing-transaction"
    "cancel-editing-transaction"
    "create-folder"
    "list-folder-items"
    "search-folders"
    "move-item-to-folder"
  ];
}
