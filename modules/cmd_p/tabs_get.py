#!/usr/bin/env python

from tabs import TabClient

def sanitize(text):
    return text.replace("&", "&amp;")

if __name__ == "__main__":
    # Formatted for rofi markup
    formatter = lambda t: sanitize(t['title']) + """<span foreground="#8a8a8a" size="small"> | """ + sanitize(t['url']) + "</span>"
    TabClient(formatter).print()
