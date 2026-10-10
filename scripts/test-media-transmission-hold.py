#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Exercise pinned Transmission startup holds against saved running torrent state."""
import base64
import hashlib
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request

BINARY = sys.argv.pop(1)


def bencode(value):
    if isinstance(value, int):
        return b'i' + str(value).encode() + b'e'
    if isinstance(value, bytes):
        return str(len(value)).encode() + b':' + value
    if isinstance(value, dict):
        return b'd' + b''.join(bencode(key) + bencode(value[key]) for key in sorted(value)) + b'e'
    raise TypeError('unsupported fixture value')


class SavedTorrentHold(unittest.TestCase):
    def test_unpaused_saved_torrent_starts_stopped_without_watch_or_network_activity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config, downloads, watch = (root / name for name in ('config', 'downloads', 'watch'))
            for path in (config, downloads, watch):
                path.mkdir()
            with socket.socket() as listener:
                listener.bind(('127.0.0.1', 0))
                port = listener.getsockname()[1]
            settings = {
                'rpc-enabled': True, 'rpc-bind-address': '127.0.0.1', 'rpc-port': port,
                'rpc-authentication-required': False, 'rpc-whitelist-enabled': False,
                'rpc-host-whitelist-enabled': False, 'download-dir': str(downloads),
                'watch-dir': str(watch), 'watch-dir-enabled': True,
                'start-added-torrents': True, 'dht-enabled': False, 'pex-enabled': False,
                'lpd-enabled': False, 'port-forwarding-enabled': False,
                'peer-bind-address-ipv4': '127.0.0.1', 'peer-bind-address-ipv6': '::1',
            }
            (config / 'settings.json').write_text(json.dumps(settings))
            piece = b'fixture partial data'
            payload = bencode({b'info': {b'name': b'held-fixture.bin', b'length': 1048576,
                                         b'piece length': 1048576,
                                         b'pieces': hashlib.sha1(b'full fixture').digest(),
                                         b'private': 1}})
            session = None
            log = (root / 'daemon.log').open('wb')

            def rpc(method, arguments=None):
                nonlocal session
                for attempt in range(2):
                    headers = {'Content-Type': 'application/json'}
                    if session:
                        headers['X-Transmission-Session-Id'] = session
                    request = urllib.request.Request('http://127.0.0.1:' + str(port) + '/transmission/rpc',
                        data=json.dumps({'method': method, 'arguments': arguments or {}}).encode(), headers=headers)
                    try:
                        with urllib.request.urlopen(request, timeout=3) as response:
                            result = json.load(response)
                        self.assertEqual(result['result'], 'success')
                        return result['arguments']
                    except urllib.error.HTTPError as error:
                        if error.code != 409 or attempt:
                            raise
                        session = error.headers['X-Transmission-Session-Id']
                raise AssertionError('session negotiation failed')

            def start(flags):
                process = subprocess.Popen([BINARY, '--foreground', '--config-dir', str(config)] + flags,
                                           stdout=log, stderr=subprocess.STDOUT)
                deadline = time.monotonic() + 15
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise AssertionError('pinned daemon exited during startup')
                    try:
                        rpc('session-get')
                        return process
                    except (OSError, urllib.error.URLError):
                        time.sleep(0.1)
                process.terminate()
                process.wait(timeout=10)
                raise AssertionError('pinned daemon did not become ready')

            def stop(process):
                process.terminate()
                process.wait(timeout=15)
                self.assertEqual(process.returncode, 0)

            process = start(['--no-watch-dir'])
            try:
                added = rpc('torrent-add', {'metainfo': base64.b64encode(payload).decode(), 'paused': False})
                identifier = added['torrent-added']['id']
                original = rpc('torrent-get', {'ids': [identifier], 'fields': ['hashString', 'totalSize', 'status']})['torrents'][0]
                self.assertNotEqual(original['status'], 0)
            finally:
                stop(process)
            saved = list((config / 'resume').glob('*.resume'))
            self.assertEqual(len(saved), 1)
            self.assertIn(b'6:pausedi0e', saved[0].read_bytes())
            partial = downloads / 'held-fixture.bin.part'
            partial.write_bytes(piece)
            watched_payload = bencode({b'info': {b'name': b'watch-fixture.bin', b'length': 1048576,
                                                 b'piece length': 1048576,
                                                 b'pieces': hashlib.sha1(b'other fixture').digest(), b'private': 1}})
            (watch / 'ignored.torrent').write_bytes(watched_payload)
            session = None
            process = start(['--paused', '--no-watch-dir'])
            try:
                for _ in range(10):
                    state = rpc('torrent-get', {'fields': ['hashString', 'totalSize', 'status', 'rateDownload', 'rateUpload']})['torrents']
                    self.assertEqual(len(state), 1)
                    self.assertEqual(state[0]['hashString'], original['hashString'])
                    self.assertEqual(state[0]['totalSize'], original['totalSize'])
                    self.assertEqual(state[0]['status'], 0)
                    self.assertEqual(state[0]['rateDownload'], 0)
                    self.assertEqual(state[0]['rateUpload'], 0)
                    self.assertEqual(partial.read_bytes(), piece)
                    time.sleep(0.5)
                self.assertTrue((watch / 'ignored.torrent').exists())
            finally:
                stop(process)
                log.close()
            persisted = json.loads((config / 'settings.json').read_text())
            watch_flag = 'watch_dir_enabled' if 'watch_dir_enabled' in persisted else 'watch-dir-enabled'
            self.assertFalse(persisted[watch_flag])


if __name__ == '__main__':
    unittest.main()
