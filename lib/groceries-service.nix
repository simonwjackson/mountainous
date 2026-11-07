# Groceries' runtime contract. No units, accounts or deployment logic here.
{ pkgs }:
{
  secrets = builtins.listToAttrs (
    map
      (name: {
        name = "groceries-${name}";
        value = ".config/groceries/${name}";
      })
      [
        "proxy-token"
        "owner-id"
        "typesafe-api-key"
        "assistant-service-token"
        "kroger-client-id"
        "kroger-client-secret"
      ]
  );
  # Upstream currently hard-codes its old agenix paths. Private file binds
  # expose real owned files, not symlinks (the app opens with O_NOFOLLOW).
  readOnlyBinds = map (name: "/run/secrets/groceries-${name}:/run/agenix/${name}") [
    "kroger-client-id"
    "kroger-client-secret"
  ];
  smokeCommand = ''
    ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 3 http://127.0.0.1:4382/healthz |
      ${pkgs.jq}/bin/jq -e '.status == "ok" and .phase == "ready" and .shoppingEnabled == true' >/dev/null
  '';
  checkCommand = ''
    "$APP_PACKAGE/bin/groceries-tsnet" --help 2>&1 | grep -q expected-fqdn
  '';
}
