#!/usr/bin/env python3
"""Read the generated OBS preference with OBS's own INI parser.

libobs keeps whitespace before '=' in key names. ConfigParser's normal spaced
output looks right to ConfigParser itself but OBS silently ignores that key.
This uses only config-file.h; it does not initialise OBS, graphics or devices.
"""

import ctypes
import os
import sys

library, path = sys.argv[1:]
obs = ctypes.CDLL(library)
obs.config_open.argtypes = [
    ctypes.POINTER(ctypes.c_void_p),
    ctypes.c_char_p,
    ctypes.c_int,
]
obs.config_open.restype = ctypes.c_int
obs.config_get_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
obs.config_get_string.restype = ctypes.c_char_p
obs.config_close.argtypes = [ctypes.c_void_p]
obs.config_close.restype = None
config = ctypes.c_void_p()
assert obs.config_open(ctypes.byref(config), os.fsencode(path), 0) == 0
try:
    actual = obs.config_get_string(config, b"Appearance", b"Theme")
    assert actual == b"com.obsproject.System", actual
finally:
    obs.config_close(config)
