>>> with this script, will the mounted directory show new files without remounting
No, the provided script does not automatically update the mounted directory when new files are added to the source directory. You would need to unmount and remount the virtual directory using the script to see the new files.

If you need a more dynamic solution, you can create a custom FUSE filesystem using Python and the `fusepy` library. This approach will allow you to see new files without remounting.

First, install `fusepy` by adding it to your `configuration.nix` file:

```nix
environment.systemPackages = with pkgs; [
  python3Packages.fusepy
];
```

Then, run `sudo nixos-rebuild switch` to apply the changes.

Next, create a Python script called `filtered_fuse.py` with the following content:

```python
#!/usr/bin/env python3

import sys
import os
import re
from fuse import FUSE, FuseOSError, Operations

class FilteredFuse(Operations):
    def __init__(self, source, patterns):
        self.source = source
        self.patterns = patterns

    def _filter_files(self, path):
        files = os.listdir(path)
        return [f for f in files if any(re.match(p, f) for p in self.patterns)]

    def getattr(self, path, fh=None):
        return os.lstat(os.path.join(self.source, path))

    def readdir(self, path, fh):
        filtered_files = self._filter_files(os.path.join(self.source, path))
        return ['.', '..'] + filtered_files

    def readlink(self, path):
        return os.readlink(os.path.join(self.source, path))

    def open(self, path, flags):
        return os.open(os.path.join(self.source, path), flags)

    def read(self, path, size, offset, fh):
        os.lseek(fh, offset, os.SEEK_SET)
        return os.read(fh, size)

    def release(self, path, fh):
        return os.close(fh)

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <source_directory> <mount_point> <pattern1> [<pattern2> ...]")
        sys.exit(1)

    source = sys.argv[1]
    mount_point = sys.argv[2]
    patterns = sys.argv[3:]

    FUSE(FilteredFuse(source, patterns), mount_point, foreground=True, nothreads=True, allow_other=False)
```

Make the script executable:

```
chmod +x filtered_fuse.py
```

Now you can use this script to mount a virtual directory with specific filter patterns. For example, if you want to show only `.txt` and `.log` files from the `/source_directory` and mount the filtered view to `/mnt/virtual_directory`, you can run:

```
./filtered_fuse.py /source_directory /mnt/virtual_directory '.*\.txt$' '.*\.log$'
```

To unmount the virtual directory, you can use the `fusermount` command:

```
fusermount -u /mnt/virtual_directory
```

With this solution, the mounted directory will show new files without remounting.
>>> i would like to have this auto mount using my configuration.nix file
To auto-mount the virtual directory using your `configuration.nix` file, you can create a systemd service that runs the `filtered_fuse.py` script at startup.

First, copy the `filtered_fuse.py` script to a location accessible by the system, such as `/etc/nixos/filtered_fuse.py`. Make sure it's executable:

```
sudo cp filtered_fuse.py /etc/nixos/filtered_fuse.py
sudo chmod +x /etc/nixos/filtered_fuse.py
```

Next, add the following to your `configuration.nix` file:

```nix
{ config, pkgs, ... }:

let
  sourceDirectory = "/source_directory";
  mountPoint = "/mnt/virtual_directory";
  patterns = [ ".*\\.txt$" ".*\\.log$" ];
in
{
  # ...

  systemd.services.filtered-fuse = {
    description = "Filtered Fuse";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3Packages.fusepy}/bin/python /etc/nixos/filtered_fuse.py ${sourceDirectory} ${mountPoint} ${toString patterns}";
      ExecStop = "${pkgs.fuse}/bin/fusermount -u ${mountPoint}";
      User = "root";
      Group = "root";
      Type = "forking";
    };
  };

  # ...
}
```

Replace `/source_directory` and `/mnt/virtual_directory` with the actual source directory and mount point paths. Update the `patterns` list with the desired filter patterns.

Finally, run `sudo nixos-rebuild switch` to apply the changes. The virtual directory will be auto-mounted at startup. To start the service immediately without rebooting, run:

```
sudo systemctl start filtered-fuse
```

To check the status of the service, run:

```
sudo systemctl status filtered-fuse
```
>>>
