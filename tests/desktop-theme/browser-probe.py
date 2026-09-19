#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages (ps: [ps.websocket-client])"
"""Check prefers-color-scheme in a new blank tab of the running Chromium."""
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request
import websocket

port = (Path.home()/'.local/share/mountainous/browser/DevToolsActivePort').read_text().splitlines()[0]
base = f'http://127.0.0.1:{int(port)}'
def request(path, method='GET'):
    with urllib.request.urlopen(urllib.request.Request(base+path, method=method), timeout=5) as response:
        return response.read()
page = json.loads(request('/json/new?about:blank', 'PUT'))
original = subprocess.check_output(['desktop-theme','status'], text=True).strip()
try:
    with websocket.create_connection(page['webSocketDebuggerUrl'], suppress_origin=True, timeout=5) as socket:
        seq = 0
        def evaluate():
            global seq
            seq += 1
            socket.send(json.dumps({'id':seq,'method':'Runtime.evaluate','params':{'expression':'matchMedia("(prefers-color-scheme: dark)").matches','returnByValue':True}}))
            while True:
                result = json.loads(socket.recv())
                if result.get('id') == seq:
                    return result['result']['result']['value']
        for mode in ['light','dark','light','dark']:
            subprocess.run(['desktop-theme',mode],check=True,stdout=subprocess.DEVNULL)
            for _ in range(30):
                actual = evaluate()
                if actual == (mode == 'dark'):
                    break
                time.sleep(0.1)
            assert actual == (mode == 'dark'), (mode,actual)
            print(f'CHROMIUM {mode}: prefers-dark={actual}',flush=True)
finally:
    request('/json/close/'+page['id'])
    subprocess.run(['desktop-theme',original],check=True,stdout=subprocess.DEVNULL)
