"""Scryer host-namespace indexers must use the VPN-owned Prowlarr proxy."""
import importlib.util
from pathlib import Path
import urllib.parse

spec = importlib.util.spec_from_file_location('common', Path(__file__).with_name('media-scryer-common.py'))
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)


def allowed_url(value):
    try:
        url = urllib.parse.urlsplit(value)
        if url.scheme not in ('http', 'https') or url.username or url.password:
            return False
        if url.hostname == '10.200.200.2':
            return url.port == 9696
        return url.hostname in ('indexers', 'indexers.hummingbird-lake.ts.net') and url.port in (None, 443, 9696)
    except (ValueError, TypeError):
        return False


def audit():
    if not common.IDENTITY.exists():
        return 'SKIP', 'Scryer indexers: protected API identity absent; provisioning required'
    try:
        client = common.Scryer.saved()
        rows = client.graphql('query{indexers{id baseUrl}}')['indexers']
        ok = all(allowed_url(row['baseUrl']) for row in rows)
        return ('PASS' if ok else 'FAIL'), f'Scryer indexers: {len(rows)} configurations checked against Prowlarr allowlist'
    except Exception:
        return 'FAIL', 'Scryer indexers: protected API read failed'
