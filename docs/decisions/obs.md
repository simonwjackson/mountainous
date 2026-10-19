# OBS virtual camera

Myoko uses OBS Studio's program output, after all its filters, as the camera
in Chromium video calls. `modules/obs.nix` sets it up behind
`mountainous.features.obs.enable`. `checks.obs-virtual-camera` tests it.

## How it works

```
camera -> OBS (scene, filters) -> Start Virtual Camera -> /dev/video63 -> Chromium
```

1. OBS reads a camera as a source:
   - The built-in ov02c10 needs libcamera, because the IPU6 gives only raw
     Bayer frames. Use the source "Video Capture Device (PipeWire)". It
     reaches the camera through the camera portal and PipeWire's libcamera
     plugin, where it shows as "Built-in Front Camera".
   - The Razer Kiyo Pro Ultra is a UVC camera. Use either "Video Capture
     Device (V4L2)" or the PipeWire source.
2. "Start Virtual Camera" in OBS writes the program output to the
   v4l2loopback device `/dev/video63`, labelled "OBS Virtual Camera".
3. Chromium lists "OBS Virtual Camera" as a camera, through V4L2.

## Decisions

- **v4l2loopback, not a PipeWire virtual camera.** OBS 32.2 on Linux has
  only the v4l2loopback virtual camera output.
- **Chromium stays on V4L2.** Measured on Myoko, 2026-10-19: Chromium 153 runs
  without `WebRtcPipeWireCamera`, so it reads cameras through V4L2. Leave that
  feature off. With it on, Chromium sees only PipeWire camera nodes.
  WirePlumber creates a node for a V4L2 device when the device appears, and
  with `exclusive_caps=1` the loopback device offers no capture at that time.
  So the virtual camera would likely not be in the list. Without the feature,
  Chromium cannot use the built-in camera directly either. That is one more
  reason to send it through OBS.
- **`exclusive_caps=1`.** The device offers capture only while OBS writes to
  it. Chromium therefore lists "OBS Virtual Camera" only while the virtual
  camera runs. It never shows a black frame from a stopped OBS.
- **`video_nr=63`, not upstream's `video_nr=1`.** The IPU6 creates
  `/dev/video0` to `/dev/video31`, and USB cameras come after it. A low
  number races the IPU6 at boot.
- **Not `programs.obs-studio.enableVirtualCamera`.** That option sets
  `video_nr=1 card_label="OBS Cam"` in a modprobe line that a host can only
  append to. The module sets the same three boot options itself.
- **Scenes and filters are not in Nix.** OBS keeps them in
  `~/.config/obs-studio`, and the user changes them in OBS.

## Limits

- The camera in a call is only live while OBS runs and its virtual camera is
  started. Start OBS before the call, or a call shows the raw cameras only.
- Audio is not routed. OBS's filtered microphone is not a Chromium microphone.
