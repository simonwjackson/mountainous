#!/nix/store/cc0wyzb5d4pxa80gm4bk8abkjr4i2kw5-python3-3.10.4/bin/python3.10
# -*- coding: utf-8 -*-
import re
import sys
from sxhkhm import main
if __name__ == '__main__':
    sys.argv[0] = re.sub(r'(-script\.pyw|\.exe)?$', '', sys.argv[0])
    sys.exit(main())
