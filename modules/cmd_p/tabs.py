#!/usr/bin/env python

import sys
import socket
import json
from operator import itemgetter

socket.setdefaulttimeout(0.5)


class TabClient:
    def __init__(self, formatter=itemgetter("title"), PORT_RS=8082):
        self.s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.s.connect(("127.0.0.1", PORT_RS))
        self.formatter = formatter
    
    def get(self):
        """
        Rust server component should return JSON list of tab data with fields `id, title, url, active`
        """
        self.s.send('GET'.encode('utf8'))
        return json.loads(read_socket(self.s))
    
    def set_tab_with_title(self, title):
        self.s.send(f'SET {title}'.encode('utf8'))
    
    def print(self):
        print("\n".join(map(self.formatter, self.get())))


def read_socket(s: socket.socket, BUFFER_SIZE=4096):
    buffer = b""
    while True:
        buffer_part = s.recv(BUFFER_SIZE)
        buffer += buffer_part

        if len(buffer_part) < BUFFER_SIZE:
            return buffer.decode('utf-8')


if __name__ == "__main__":
    c = TabClient()

    if len(sys.argv) > 1:
        c.set_tab_with_title(sys.argv[1])
    else:
        # Default formatter just prints titles (plain rofi mode)
        c.print()
 
