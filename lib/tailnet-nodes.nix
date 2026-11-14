# Stable Tailscale node IDs (`tailscale status --json`: `.ID`), keyed by the
# node's current name. Grants match these, never a node name: a removed
# node's name can be registered again by another node, and a rename keeps
# the ID. A node that registers again gets a new ID; change it here only.
{
  # Simon's OpenClaw gateway (container claw-simon on Yari). Named claw-simon
  # until the in-place rename on 2026-11-14; the ID did not change.
  flakey = "nbQJZMcewG11CNTRL";
  # Laure's OpenClaw gateway (container openclaw on Yari). Named claw until
  # the in-place rename to snowy; the ID does not change.
  snowy = "nkT3Yhzyy121CNTRL";
  zao = "nto5J2nGb311CNTRL";
}
