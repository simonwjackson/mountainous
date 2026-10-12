#!/usr/bin/env python3
"""Read-only audit: does every downloader byte and DNS query leave through wg-vpn? Runs as root on Unzen."""
import json
import os
from pathlib import Path
import re
import socket
import sqlite3
import subprocess
import time
import uuid
if os.getuid() != 0 or socket.gethostname() != 'unzen':
    raise SystemExit('Refused: incorrect host')
results = []
def check(name, ok, detail=''):
    results.append((name, bool(ok), detail))
def run(*cmd, ns=False):
    cmd = (['ip', 'netns', 'exec', 'vpn'] if ns else []) + list(cmd)
    r = subprocess.run(cmd, capture_output=True, text=True)
    return (r.stdout + r.stderr).strip()

vpn_ino = os.stat('/run/netns/vpn').st_ino
host_ino = os.stat('/proc/1/ns/net').st_ino
vpn_units = ['prowlarr.service', 'nzbget.service', 'nzbfast.service', 'transmission.service']
# 1. Every process of the downloader-side services, including children, is in the VPN namespace.
for unit in vpn_units:
    cgroup = run('systemctl', 'show', unit, '-p', 'ControlGroup', '--value')
    if not cgroup or not cgroup.startswith('/'):
        check(f'{unit}: active cgroup exists', False)
        continue
    procs = Path('/sys/fs/cgroup' + cgroup + '/cgroup.procs').read_text().split()
    sub = [p for d in Path('/sys/fs/cgroup' + cgroup).rglob('cgroup.procs') for p in d.read_text().split()]
    pids = sorted(set(procs + sub))
    outside = [p for p in pids if os.stat(f'/proc/{p}/ns/net').st_ino != vpn_ino]
    check(f'{unit}: all {len(pids)} process(es) in the vpn namespace', pids and not outside, f'outside={outside}')
# Sonarr/Radarr are by design outside; record it.
for unit in ['sonarr.service', 'radarr.service']:
    pid = run('systemctl', 'show', unit, '-p', 'MainPID', '--value')
    check(f'{unit}: runs in host namespace (by design, does not download)', os.stat(f'/proc/{pid}/ns/net').st_ino == host_ino)

# 2. Namespace interfaces and routes.
links = json.loads(run('ip', '-j', 'link', ns=True))
names = sorted(l['ifname'] for l in links)
check('namespace has only lo, wg-vpn, veth-vpn-ns', names == ['lo', 'veth-vpn-ns', 'wg-vpn'], str(names))
routes4 = json.loads(run('ip', '-j', '-4', 'route', 'show', 'table', 'all', ns=True))
defaults = [r for r in routes4 if r.get('dst') == 'default']
check('only IPv4 default route is dev wg-vpn', len(defaults) == 1 and defaults[0].get('dev') == 'wg-vpn', str(defaults))
veth_routes = [r['dst'] for r in routes4 if r.get('dev') == 'veth-vpn-ns' and r.get('table', 'main') == 'main']
check('only tailnet and veth subnet route via host', set(veth_routes) <= {'100.64.0.0/10', '10.200.200.0/24'}, str(veth_routes))
rules = run('ip', 'rule', ns=True)
check('no policy-routing rules that could bypass main table', len(rules.splitlines()) == 3, rules)
for target in ['1.1.1.1', '8.8.8.8', '185.199.108.153', '23.0.0.1', '192.168.1.1', '10.0.0.1', '172.16.0.1']:
    route = run('ip', 'route', 'get', target, ns=True)
    check(f'route to {target} uses wg-vpn', 'dev wg-vpn' in route, route)
addrs6 = json.loads(run('ip', '-j', '-6', 'addr', ns=True))
global6 = [a['local'] for l in addrs6 for a in l.get('addr_info', []) if a.get('scope') == 'global']
routes6 = run('ip', '-6', 'route', 'show', 'table', 'all', ns=True)
v6_out = run('curl', '-6', '-sS', '--max-time', '8', 'https://ifconfig.io/ip', ns=True)
check('IPv6 cannot leave the namespace except via wg-vpn', not global6 or 'dev wg-vpn' in routes6, f'global6={global6}; routes6={routes6!r}; curl -6 -> {v6_out[:80]}')

# 3. Tunnel health and egress identity.
wg = run('wg', 'show', 'wg-vpn', 'latest-handshakes', ns=True)
age = time.time() - int(wg.split()[-1]) if wg.split() and wg.split()[-1].isdigit() else 1e9
check('WireGuard handshake is recent (< 3 min)', age < 180, f'{int(age)}s')
ns_ip = run('curl', '-4', '-fsS', '--max-time', '10', 'https://ifconfig.io/ip', ns=True)
host_ip = run('curl', '-4', '-fsS', '--max-time', '10', 'https://ifconfig.io/ip')
check('namespace public IP differs from Unzen public IP', ns_ip and host_ip and ns_ip != host_ip, f'vpn={ns_ip} host={host_ip}')

# 4. Every live socket of the downloader services leaves via wg-vpn, lo, or the tailnet/veth.
ss = run('ss', '-Htunap', ns=True)
bad = []
count = 0
for line in ss.splitlines():
    parts = line.split()
    if len(parts) < 6 or parts[1] in ('LISTEN', 'UNCONN'):
        continue
    peer = parts[5].rsplit(':', 1)[0].strip('[]')
    # IPv4-mapped IPv6 sockets (.NET) carry plain IPv4 traffic.
    if peer.startswith('::ffff:') and '.' in peer:
        peer = peer[len('::ffff:'):]
    if peer in ('*', '0.0.0.0', '::') or peer.startswith(('127.', '::1')):
        continue
    count += 1
    route = run('ip', 'route', 'get', peer, ns=True)
    if 'dev wg-vpn' not in route and not peer.startswith(('100.', '10.200.200.', 'fd7a:')):
        bad.append(f'{peer} -> {route}')
check(f'all {count} live remote connections route via wg-vpn (tailnet/veth excepted)', not bad, '; '.join(bad[:5]))

# 5. DNS: resolve a unique name inside an actual service's own namespaces while watching the host for port-53 traffic.
for unit in ['nzbget.service', 'nzbfast.service']:
    pid = run('systemctl', 'show', unit, '-p', 'MainPID', '--value')
    if not pid.isdigit() or pid == '0':
        check(f'{unit}: running for DNS audit', False)
        continue
    resolv = run('nsenter', '-t', pid, '-m', 'cat', '/etc/resolv.conf')
    dns_ip = (re.findall(r'nameserver\s+(\S+)', resolv) or [''])[0]
    check(f'{unit}: resolv.conf uses VPN DNS routed via wg-vpn', dns_ip and 'dev wg-vpn' in run('ip', 'route', 'get', dns_ip, ns=True), resolv)
    socket_check = subprocess.run(['nsenter', '-t', pid, '-m', 'test', '-S', '/run/nscd/socket'])
    check(f'{unit}: host nscd socket is hidden', socket_check.returncode != 0)
    environment = Path(f'/proc/{pid}/environ').read_bytes().decode().split('\0')
    nss = next((item for item in environment if item.startswith('LD_LIBRARY_PATH=')), 'LD_LIBRARY_PATH=')
    check(f'{unit}: VPN NSS modules are configured', nss != 'LD_LIBRARY_PATH=')
    lookup = ['nsenter', '-t', pid, '-n', '-m', 'env', nss, 'getent', 'ahosts']
    name = f'vpn-leak-{uuid.uuid4().hex[:12]}.example.com'
    capture = subprocess.Popen(['timeout', '12', 'tcpdump', '-i', 'any', '-nn', '-l', '-A', 'port 53'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    time.sleep(2)
    subprocess.run(lookup + [name], capture_output=True, text=True)
    host_saw = name.split('.')[0] in capture.communicate()[0]
    check(f'{unit}: DNS lookup is NOT seen on host interfaces', not host_saw)
    ns_capture = subprocess.Popen(['timeout', '12', 'ip', 'netns', 'exec', 'vpn', 'tcpdump', '-i', 'wg-vpn', '-nn', '-l', '-A', 'port 53'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    time.sleep(2)
    name2 = f'vpn-leak-{uuid.uuid4().hex[:12]}.example.com'
    subprocess.run(lookup + [name2], capture_output=True, text=True)
    check(f'{unit}: DNS lookup IS seen going out wg-vpn', name2.split('.')[0] in ns_capture.communicate()[0])

# 6. Indexer redirect would make Sonarr/Radarr fetch NZBs directly from the indexer, outside the VPN.
with sqlite3.connect('file:/var/lib/prowlarr/prowlarr.db?mode=ro', uri=True) as db:
    rows = [(r[0], r[1], json.loads(r[2])) for r in db.execute('SELECT Id, Implementation, Settings FROM Indexers')]
redirect = [f'{i}:{impl}' for i, impl, s in rows if s.get('redirect')]
check('no Prowlarr indexer uses redirect (NZB downloads proxied through the VPN)', not redirect, str(redirect))
for app, path in [('sonarr', '/var/lib/sonarr/.config/NzbDrone/sonarr.db'), ('radarr', '/var/lib/radarr/.config/Radarr/radarr.db')]:
    with sqlite3.connect(f'file:{path}?mode=ro', uri=True) as db:
        urls = [json.loads(s).get('baseUrl', '') for (s,) in db.execute('SELECT Settings FROM Indexers')]
    check(f'{app}: every indexer points at Prowlarr, not an indexer directly', urls and all('indexers.hummingbird-lake.ts.net' in u or '10.200.200.2' in u for u in urls), str([re.sub(r'/api.*', '', u) for u in urls]))

# 7. Kill switch by design: unit binding.
for unit in vpn_units:
    props = run('systemctl', 'show', unit, '-p', 'BindsTo', '-p', 'NetworkNamespacePath')
    check(f'{unit} BindsTo media-vpn and is pinned to /run/netns/vpn', 'media-vpn.service' in props and '/run/netns/vpn' in props, props)

for name, ok, detail in results:
    print(('PASS ' if ok else 'FAIL ') + name + ('' if ok or not detail else '  -> ' + detail[:400]))
print(f'\n{sum(ok for _, ok, _ in results)}/{len(results)} checks passed')
