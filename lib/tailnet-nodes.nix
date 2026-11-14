# Stable Tailscale node IDs (`tailscale status --json`: `.ID`), keyed by the
# node's current name. Grants match these, never a node name: a removed
# node's name can be registered again by another node, and a rename keeps
# the ID. A node that registers again gets a new ID; change it here only.
{
  # flakey, Simon's OpenClaw gateway (container claw-simon on Yari).
  claw-simon = "nbQJZMcewG11CNTRL";
  zao = "nto5J2nGb311CNTRL";
}
