# Samsung 960QFG camera trial

The 6.18.52 camera trial below is historical. Myoko now selects
`linuxPackages_latest` from the locked nixpkgs revision. The 6.18-only
patch series is kept for reference but is not applied to that kernel.
Camera capture on the new kernel is unverified until the patches are
ported or equivalent support is confirmed upstream. Hiyori's recovery
USB keeps the default kernel.

The installed Myoko is the Galaxy Book3 Pro 360 NP960QFG-KA1US. On its original Linux 6.18.52 kernel, `ov02c10` failed probe with `external clock 26000000 is not supported`. Its ACPI sensor ID is `OVTI02C1:00`, and its IPU6 PCI device is `8086:a75d`.

Myoko alone carries Felipe Calliari's [September 23, 2026 v3 series](https://ratatoskr.run/linux-media/2026/09/17632924). Patches 1–5 are retained as diff-only files under `modules/galaxy-book3-camera/`, in upstream order. They adjust the OV02C10 PLL for a 26 MHz input, advertise a 399479167 Hz link frequency in the IPU bridge, and implement crop selection. Upstream's cover letter reports frame-capture testing on a Galaxy Book3 Ultra, not this 960QFG. The sixth local patch removes the `v4l2_subdev_client_info` argument from `get_selection` because the 6.18.52 callback ABI does not have it. The first full build failed with that incompatible pointer type. The second build passed. `scripts/test-myoko-camera-patches` checks that all six patches apply to the locked kernel source.

On the 960QFG one-shot boot, `/run/booted-system` was `/nix/store/89p9i40hz567zl07g0cczbgs076vq8hi-nixos-system-myoko-26.11.20260916.b1b8759`. `ov02c10` bound on `i2c-OVTI02C1:00`; `/dev/v4l-subdev4` reported link frequency `399479167` and pixel rate `159791666`. The IPU6 media graph linked the sensor to CSI2 0. `libcamera 0.7.2` listed `Internal front camera` and `cam -c1 --capture=5` returned four frames with 8386560 bytes each at about 30 fps. The first reported frame had zero bytes; there was one `csi2-0 error: Frame sync error` at startup. No failed system units were listed. `bootctl` still showed generation 3 as the default and generation 2 as another available boot entry.

This test proves sensor binding and nonempty capture buffers, not image orientation, colour, or application integration. libcamera warned that it lacks static OV02C10 properties, a dedicated `ov02c10.yaml`, and a sensor helper. The 960QFG reports `camera_sensor_rotation=0`. A separate [upstream upside-down quirk](https://ratatoskr.run/linux-media/2026/09/17630204) is for product name `960XFG`, not the measured `960QFG`; do not assume it matches this machine. Check a visible frame before adding a rotation quirk or claiming calibrated image quality.
