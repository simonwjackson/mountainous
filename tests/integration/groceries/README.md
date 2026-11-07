# Groceries integration probes

These are product-specific tests, not reusable migration tools. `probe` reads
public health and authenticated household context, prints only build metadata,
line count and a digest, and sends credentials to curl through stdin.

`assistant-probes PYTHON_ON_RAKKU PROBE_ON_RAKKU EVIDENCE_DIRECTORY` reads each
assistant unit's actual `User=` and uses its installed credential file. Run it
only against an already-serving groceries endpoint. It does not manage units.
The three personas and credential paths are groceries' current integration
contract, intentionally kept out of generic `scripts/service-apps-*` tools.
