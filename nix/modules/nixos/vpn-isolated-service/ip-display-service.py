#!/usr/bin/env python3
import http.server
import socketserver
import subprocess
import json
import time
import os
import sys

def log_message(msg):
    print(f'[IP-Display] {msg}', file=sys.stderr, flush=True)

def get_ip_info_with_retry(max_retries=3):
    '''Get IP info with retry logic and comprehensive error handling'''
    
    # Set up proper environment for subprocess
    env = os.environ.copy()
    env.update({
        'PATH': '/run/current-system/sw/bin',
        'SSL_CERT_FILE': '/etc/ssl/certs/ca-bundle.crt'
    })
    
    for attempt in range(max_retries):
        try:
            log_message(f'Attempt {attempt + 1}/{max_retries}: Fetching IP info...')
            
            # Primary method: ipinfo.io
            result = subprocess.run([
                'curl', 
                '-s', 
                '--connect-timeout', '5', 
                '--max-time', '10', 
                '--retry', '2',
                '--cacert', '/etc/ssl/certs/ca-bundle.crt',
                'https://ipinfo.io/json'
            ], capture_output=True, text=True, timeout=15, env=env)
            
            log_message(f'Curl return code: {result.returncode}')
            if result.stderr:
                log_message(f'Curl stderr: {result.stderr}')
            
            if result.returncode == 0 and result.stdout.strip():
                try:
                    ip_info = json.loads(result.stdout)
                    log_message(f'Successfully parsed JSON: {ip_info}')
                    return {
                        'ip': ip_info.get('ip', 'Unknown'),
                        'city': ip_info.get('city', 'Unknown'),
                        'region': ip_info.get('region', 'Unknown'),
                        'country': ip_info.get('country', 'Unknown'),
                        'org': ip_info.get('org', 'Unknown'),
                        'status': 'Connected'
                    }
                except json.JSONDecodeError as e:
                    log_message(f'JSON decode error: {e}, raw output: {result.stdout[:200]}')
            else:
                log_message(f'Curl failed - stdout: {result.stdout[:200]}, stderr: {result.stderr[:200]}')
            
            # Fallback method: Simple IP only
            if attempt == max_retries - 1:
                log_message('Trying fallback method: httpbin.org/ip')
                result = subprocess.run([
                    'curl', 
                    '-s', 
                    '--connect-timeout', '5', 
                    '--max-time', '10',
                    '--cacert', '/etc/ssl/certs/ca-bundle.crt',
                    'https://httpbin.org/ip'
                ], capture_output=True, text=True, timeout=15, env=env)
                
                if result.returncode == 0 and result.stdout.strip():
                    try:
                        ip_data = json.loads(result.stdout)
                        ip = ip_data.get('origin', 'Unknown')
                        log_message(f'Fallback IP retrieved: {ip}')
                        return {
                            'ip': ip,
                            'city': 'VPN Location',
                            'region': 'Unknown',
                            'country': 'Unknown',
                            'org': 'VPN Provider',
                            'status': 'Connected (Limited Info)'
                        }
                    except json.JSONDecodeError as e:
                        log_message(f'Fallback JSON decode error: {e}')
            
            # Wait before retry (exponential backoff)
            if attempt < max_retries - 1:
                wait_time = 2 ** attempt
                log_message(f'Waiting {wait_time}s before retry...')
                time.sleep(wait_time)
                
        except subprocess.TimeoutExpired as e:
            log_message(f'Subprocess timeout: {e}')
        except Exception as e:
            log_message(f'Unexpected error: {type(e).__name__}: {e}')
    
    # All attempts failed
    log_message('All IP detection attempts failed')
    return {
        'ip': 'Detection Failed',
        'city': 'See logs for details',
        'region': 'Check journal',
        'country': 'systemctl logs',
        'org': 'ip-display.service',
        'status': 'Error - Check Logs'
    }

class IPHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        
        log_message('Handling HTTP request...')
        ip_info = get_ip_info_with_retry()
        
        # Determine CSS class for status box
        if ip_info['status'].startswith('Connected'):
            status_class = 'connected'
        elif 'Error' in ip_info['status']:
            status_class = 'error'
        else:
            status_class = ''
        
        # Build HTML using f-strings (safe in separate file)
        html = f'''<!DOCTYPE html>
<html>
<head>
    <title>VPN IP Check</title>
    <meta http-equiv="refresh" content="10">
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; }}
        .status-box {{ background: #f0f8ff; padding: 20px; border-radius: 8px; margin: 20px 0; }}
        .connected {{ background: #f0fff0; border: 2px solid #90EE90; }}
        .error {{ background: #fff0f0; border: 2px solid #FFB6C1; }}
    </style>
</head>
<body>
    <h1>VPN IP Verification</h1>
    <div class="status-box {status_class}">
        <h2>Status: {ip_info['status']}</h2>
        <h2>Public IP: {ip_info['ip']}</h2>
        <p><strong>Location:</strong> {ip_info['city']}, {ip_info['region']}, {ip_info['country']}</p>
        <p><strong>Organization:</strong> {ip_info['org']}</p>
        <p><strong>Last Updated:</strong> {time.strftime('%Y-%m-%d %H:%M:%S')}</p>
    </div>
    <hr>
    <small>Served from VPN namespace - Auto-refreshing every 10 seconds<br>
    Check 'journalctl -u ip-display.service' for debug logs</small>
</body>
</html>'''
        
        self.wfile.write(html.encode())

log_message('Starting IP display server...')
with socketserver.TCPServer(('192.168.15.1', 8888), IPHandler) as httpd:
    log_message('IP display server running on 192.168.15.1:8888...')
    httpd.serve_forever()