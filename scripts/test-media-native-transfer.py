#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 rsync gnutar
"""Prove native archive and mapped rsync preserve the full move contract."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

loader = importlib.machinery.SourceFileLoader('state', str(Path(__file__).with_name('media-state')))
spec = importlib.util.spec_from_loader(loader.name, loader)
state = importlib.util.module_from_spec(spec)
loader.exec_module(state)


class NativeTransfer(unittest.TestCase):
    def test_archive_and_numeric_acl_mapping_preserve_private_layout_and_work(self):
        self.assertEqual(os.getuid(), 0, 'native ownership admission must run as root')
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            source, incoming, mapped = (base / name for name in ('source', 'incoming', 'mapped'))
            for path in (source, incoming, mapped):
                path.mkdir(mode=0o700)
            roots = ['var/lib/sonarr', 'var/lib/prowlarr', 'var/lib/private/prowlarr',
                     'var/lib/tsnet-proxy-sonarr', 'srv/basin/downloads', 'srv/basin/media']
            for root in roots:
                if root != 'var/lib/prowlarr':
                    (source / root).mkdir(parents=True)
            (source / 'var/lib/prowlarr').symlink_to('/var/lib/private/prowlarr')
            private = source / 'var/lib/private/prowlarr/config.xml'
            private.write_bytes(b'private fixture credential')
            private.chmod(0o600)
            os.chown(private, 65534, 65534)
            work = source / 'srv/basin/downloads/.partial'
            work.write_bytes(b'partial archive\0' * 1000)
            (source / 'srv/basin/media/imported').hardlink_to(work)
            os.chown(work, 245, 993)
            os.chmod(work, 0o660)
            settings = source / 'var/lib/sonarr/.settings'
            settings.write_bytes(b'preserved setting\0')
            os.chown(settings, 274, 993)
            settings.chmod(0o640)
            acl = [(1, 6, 0xffffffff), (2, 4, 995), (4, 4, 0xffffffff),
                   (8, 4, 992), (16, 4, 0xffffffff), (32, 0, 0xffffffff)]
            os.setxattr(settings, 'system.posix_acl_access', struct.pack('<I', 2) +
                        b''.join(struct.pack('<HHI', *entry) for entry in acl))
            os.setxattr(settings, 'user.protected', b'private fixture xattr')
            proxy = source / 'var/lib/tsnet-proxy-sonarr/tailscaled.state'
            proxy.write_bytes(b'preserved identity fixture')
            os.chown(proxy, 995, 992)
            proxy.chmod(0o600)
            for root in roots:
                path = source / root
                if not path.is_symlink():
                    if root != 'var/lib/private/prowlarr':
                        os.chown(path, 0, 993)
                        path.chmod(0o2775)
                    else:
                        os.chown(path, 65534, 65534)
                        path.chmod(0o700)
                info = path.lstat()
                os.utime(path, ns=(info.st_atime_ns, 1700000000123456789), follow_symlinks=False)
            for path in (work, settings, private, proxy):
                os.utime(path, ns=(1700000000123456789, 1700000000123456789))
            expected = state.capture_scope(source, roots)
            archive = base / 'state.tar'
            subprocess.run(['tar', '--format=posix', '--acls', '--xattrs', '--xattrs-include=*',
                            '--numeric-owner', '--sparse', '-cf', str(archive), '-C', str(source),
                            '--'] + roots, check=True, capture_output=True)
            archive.chmod(0o600)
            subprocess.run(['tar', '--acls', '--xattrs', '--xattrs-include=*', '--numeric-owner',
                            '--same-owner', '--same-permissions', '-xf', str(archive), '-C', str(incoming)],
                           check=True, capture_output=True)
            state.verify(expected, state.capture_scope(incoming, roots))
            subprocess.run(['rsync', '-aHAXS', '--numeric-ids', '--usermap=995:395',
                            '--groupmap=993:390,992:391', str(incoming) + '/', str(mapped) + '/'],
                           check=True, capture_output=True)
            # The local native transfer changes file ownership but leaves named
            # ACL IDs unchanged. Explicit mapping must admit all other fields.
            with self.assertRaises(state.StateError):
                state.verify(expected, state.capture_scope(mapped, roots),
                             uid_map={995: 395}, gid_map={993: 390, 992: 391})
            mapped_settings = mapped / 'var/lib/sonarr/.settings'
            previous_acl = os.getxattr(mapped_settings, 'system.posix_acl_access')
            mapped_work = mapped / 'srv/basin/downloads/.partial'
            previous = mapped_work.stat()
            data = mapped_work.read_bytes()
            mapped_work.write_bytes(b'X' * len(data))
            with self.assertRaises(state.StateError):
                state.map_scope_acls(mapped, roots, expected, {995: 395}, {993: 390, 992: 391})
            self.assertEqual(os.getxattr(mapped_settings, 'system.posix_acl_access'), previous_acl)
            mapped_work.write_bytes(data)
            os.utime(mapped_work, ns=(previous.st_atime_ns, previous.st_mtime_ns))
            state.map_scope_acls(mapped, roots, expected, {995: 395}, {993: 390, 992: 391})
            state.verify(expected, state.capture_scope(mapped, roots),
                         uid_map={995: 395}, gid_map={993: 390, 992: 391})
            state.map_scope_acls(mapped, roots, expected, {995: 395}, {993: 390, 992: 391})
            self.assertEqual(os.readlink(mapped / 'var/lib/prowlarr'), '/var/lib/private/prowlarr')
            self.assertEqual((mapped / 'srv/basin/downloads/.partial').stat().st_ino,
                             (mapped / 'srv/basin/media/imported').stat().st_ino)
            self.assertEqual((mapped / 'var/lib/private/prowlarr/config.xml').stat().st_uid, 65534)
            self.assertEqual((mapped / 'var/lib/tsnet-proxy-sonarr/tailscaled.state').stat().st_uid, 395)

            # Rollback must return newer target writes, not the frozen original.
            mapped_proxy = mapped / 'var/lib/tsnet-proxy-sonarr/tailscaled.state'
            mapped_proxy.write_bytes(b'newest target identity fixture')
            mapped_work.write_bytes(data + b'newest target partial bytes')
            latest = state.capture_scope(mapped, roots)
            rollback = base / 'rollback'
            rollback.mkdir(mode=0o700)
            subprocess.run(['rsync', '-aHAXS', '--numeric-ids', '--usermap=395:995',
                            '--groupmap=390:993,391:992', str(mapped) + '/', str(rollback) + '/'],
                           check=True, capture_output=True)
            with self.assertRaises(state.StateError):
                state.verify(latest, state.capture_scope(rollback, roots),
                             uid_map={395: 995}, gid_map={390: 993, 391: 992})
            state.map_scope_acls(rollback, roots, latest, {395: 995}, {390: 993, 391: 992})
            actual = state.capture_scope(rollback, roots)
            state.verify(latest, actual, uid_map={395: 995}, gid_map={390: 993, 391: 992})
            with self.assertRaises(state.StateError):
                state.verify(expected, actual)
            self.assertEqual((rollback / 'var/lib/tsnet-proxy-sonarr/tailscaled.state').read_bytes(),
                             b'newest target identity fixture')
            self.assertEqual((rollback / 'srv/basin/downloads/.partial').read_bytes(),
                             data + b'newest target partial bytes')
            self.assertEqual((rollback / 'var/lib/tsnet-proxy-sonarr/tailscaled.state').stat().st_uid, 995)
            self.assertEqual((rollback / 'var/lib/tsnet-proxy-sonarr/tailscaled.state').stat().st_gid, 992)
            self.assertEqual((rollback / 'var/lib/private/prowlarr/config.xml').stat().st_uid, 65534)
            self.assertEqual((rollback / 'srv/basin/downloads/.partial').stat().st_ino,
                             (rollback / 'srv/basin/media/imported').stat().st_ino)
            self.assertEqual(os.readlink(rollback / 'var/lib/prowlarr'), '/var/lib/private/prowlarr')
            self.assertEqual((rollback / 'var/lib/sonarr').stat().st_uid, 0)


if __name__ == '__main__':
    unittest.main()
