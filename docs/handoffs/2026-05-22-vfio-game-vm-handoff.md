# Handoff: Game-freezing / VM GPU experiments for `aka` + future VFIO test on `zao`

## Intended next session
Pick up later to test **VFIO passthrough + guest-side hibernation** as the next path toward near-native game performance and per-game freeze/thaw. Likely first target: `zao` XPS 17 laptop with Intel iGPU + RTX 3060 Mobile, then possibly `aka` with iGPU host + RX 7900 XT guest.

Suggested skills: `se-work`, `se-debug`, `web-search` as needed. If turning this into NixOS modules, use `se-plan` first.

## Existing artifacts / files
- Research report: `docs/reports/2026-05-20-freezing-games-on-aka.md`
  - It is now partially outdated: it originally favored Venus + `savevm`, but later experiments proved `savevm`/migration is blocked for virgl/Venus.
- Prototype control script:
  - Local: `/tmp/venus-vm.sh`
  - Remote on `aka`: `/tmp/venus-vm.sh`
  - Uses nix-shell, no libvirt, no persistent system config changes.
- Persistent VM state dir on `aka`: `/tmp/venus-vm`
- Guest scratch disk inside VM: `/dev/vda`, formatted ext4 and mounted at `/mnt/work` during live ISO sessions.
- Guest benchmark artifacts persisted under `/mnt/work/bench` on that qcow2 disk.
- Host benchmark artifacts on `aka`: `/tmp/gm-host/`

## Important user preferences / constraints
- User wants autonomous remote work, not manual copy/paste instructions.
- Use `ssh -F /dev/null aka` / `ssh -F /dev/null zao`.
- Current experiments are throwaway/prototype; avoid destructive host config unless explicitly approved.
- User is interested in **mostly Proton/DXVK/VKD3D games**.
- Steam cannot currently be installed, so tests used plain Wine + DXVK rather than Steam/Proton.

## Venus VM prototype on `aka`: what worked
Host `aka`:
- AMD Ryzen 5 7600X, RX 7900 XT, iGPU also present.
- QEMU 10.2.2, virglrenderer 1.3.0, Mesa 26.x.
- `/dev/kvm` accessible.
- Wayland socket usually `/run/user/1000/wayland-1`.

`/tmp/venus-vm.sh` features now include:
- `start` background boot
- unix monitor socket, QMP socket, serial socket
- `mon`, `sendkey`, `sendstring`, `screenshot`, `status`, `quit`, `log`, etc.
- `hostfwd=tcp:127.0.0.1:2222-:22`
- `-vga none` (critical; otherwise Bochs/secondary VGA steals scanout / black screen)
- `virtio-gpu-gl-pci,venus=on,hostmem=...,max_hostmem=...,blob=true`
- NixOS Vulkan loader path fix for host `virgl_render_server`: script finds `libvulkan.so.1` and prefixes `LD_LIBRARY_PATH`; also prefixes `/run/opengl-driver/share` into `XDG_DATA_DIRS`.
- Tunables: `DISPLAY_BACKEND=sdl|gtk|spice`, `SMP`, `RAM`, `HOSTMEM`, `MAX_HOSTMEM`.

Fedora Sway guest notes:
- Fedora Sway live ISO boots and renders.
- Live ISO defaults Sway to software renderer under KVM:
  - `WLR_RENDERER=pixman WLR_DRM_NO_ATOMIC=1`
- For hardware-rendered Wayland clients, override in guest:
  ```sh
  mkdir -p ~/.config/sway
  cat > ~/.config/sway/environment <<'EOF'
  WLR_RENDERER=gles2
  unset WLR_DRM_NO_ATOMIC
  WLR_NO_HARDWARE_CURSORS=1
  EOF
  sudo systemctl restart sddm
  ```
- After this, `glmark2-wayland` reported:
  - `GL_RENDERER: virgl (AMD Radeon RX 7900 XT ...)`
- XWayland Vulkan through Venus works after the GLES override.

Guest SSH setup after each live boot:
```sh
# driven through /tmp/venus-vm.sh sendstring/sendkey or TTY
liveuser
# then:
echo liveuser:fedora | sudo chpasswd && sudo systemctl start sshd
# connect from aka host:
sshpass -p fedora ssh -p 2222 liveuser@127.0.0.1 ...
```

## Critical finding: Venus + QEMU `savevm` is impossible today
Attempted `savevm` and migration with active virtio-gpu-gl/Venus failed:
```text
Error: virgl is not yet migratable
Outgoing migration blocked:
  virgl is not yet migratable
```
Conclusion:
- QEMU host-side `savevm`/`migrate` cannot be used with virtio-gpu-gl/Venus.
- The viable freeze mechanism for VMs is **guest-side hibernation (ACPI S4)**, not QEMU snapshots.

## Guest hibernation conceptual conclusion
Guest-side hibernation is not exactly `savevm`:
- Guest/kernel/drivers know it is sleeping; network/audio/GPU reset callbacks run.
- Wall-clock jumps on resume.
- Online games will lose server sessions.
- Single-player/offline games have a good chance of staying active.
- For VFIO, QEMU migration is also impossible, so guest-side hibernation is the path there too.

## Benchmarks already run
### Misleading OpenGL/virgl benchmark
`glmark2-wayland` host vs guest showed guest only ~17% of host at 1280x720:
- Guest virgl: score `2518`
- Host native: score `14350`
Conclusion: not representative of Proton/DXVK/VKD3D target; it measures old virgl OpenGL and compositor/VM window overhead.

### Relevant Proton-like benchmark: Windows GravityMark D3D11 via Wine + DXVK
Used Windows GravityMark 1.89 MSI, extracted with `msitools`, not installed. Guest used Fedora `wine-core` + `wine-dxvk` packages; host used Nix `wine64` + `dxvk`.

Guest stack:
```text
GravityMark.exe D3D11
→ Wine
→ DXVK 2.7.1
→ Vulkan
→ Virtio-GPU Venus
→ host RADV / RX 7900 XT
```

Important guest setup for benchmarks:
```sh
# persistent scratch disk
sudo mount /dev/vda /mnt/work
sudo mount --bind /mnt/work/dnf-cache /var/cache/dnf

# install on live ISO when needed
sudo dnf install -y --setopt=keepcache=0 \
  wine-core wine-dxvk wine-dxvk-dxgi wine-dxvk-d3d9 wine-dxvk-d3d10 \
  vulkan-tools cabextract unzip curl msitools

# DXVK overrides in prefix
export WINEPREFIX=/mnt/work/wineprefix/gm
for dll in d3d8 d3d9 d3d10core d3d11 dxgi; do
  wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v "$dll" /d native,builtin /f >/dev/null
done
```

GravityMark extraction:
- Guest: `/mnt/work/bench/gm-msi/GravityMark/bin/GravityMark.exe`
- Host: `/tmp/gm-host/gm-msi/GravityMark/bin/GravityMark.exe`

Initial smaller/odd-size run:
- Guest requested 1280x720 but actual buffer 956x720:
  - Score `34210`, FPS `204.8`
- Host 1280x720:
  - Score `46802`, FPS `280.2`
- Host 956x720 oddly slower:
  - Score `33628`, FPS `201.4`
Conclusion: GravityMark scoring is not monotonic with weird window size; do not overinterpret.

More relevant 1080-ish run:
- Guest windowed, output 1920x1080, actual DXVK buffer `1920x1067`:
  - Score `33832`, FPS `202.6`
- Host windowed, actual DXVK buffer `1920x1060`:
  - Score `55206`, FPS `330.5`
- Guest/host ≈ `61.3%`.

“Big swing” attempts:
1. Restart VM with `SMP=12 RAM=16G HOSTMEM=8G MAX_HOSTMEM=16G`, host QEMU GTK fullscreen:
   - Guest fullscreen actual buffer `1920x1080`: score `14300`, FPS `85.6`.
   - Guest windowed actual buffer `1920x1067`: score `10512`, FPS `62.9`.
   - Much worse. Likely host QEMU fullscreen/GTK presentation bottleneck.
2. Restart with `DISPLAY_BACKEND=sdl SMP=8 RAM=12G HOSTMEM=4G MAX_HOSTMEM=8G`:
   - Guest windowed actual buffer `1920x1067`: score `32803`, FPS `196.4`.
   - Similar/slightly worse than good GTK windowed result.

Conclusion from benchmarks:
- Venus/DXVK is **much better than virgl OpenGL**, but still ~60% of host at 1080p in this QEMU-window presentation setup.
- Simple knobs (more vCPU, more hostmem, fullscreen GTK, SDL) did not get closer to 100%.
- Bottleneck likely presentation/virtio-gpu/Venus path, not raw CPU count.

## Next architecture recommendation
For close-to-native performance, test **VFIO passthrough + Sunshine inside guest**:
```text
host runs on iGPU
VM owns physical dGPU via VFIO
Sunshine runs inside guest
Moonlight connects to guest Sunshine
freeze/thaw = guest-side hibernation
```
Only one VM can own one physical GPU at a time. Multiple game VMs can be hibernated on disk, but only one can run with the GPU.

## `aka` VFIO capability check
`aka` has:
- RX 7900 XT: `03:00.0 [1002:744c]`
- RX 7900 XT HDMI/DP audio: `03:00.1 [1002:ab30]`
- Ryzen iGPU: `0f:00.0 [1002:164e]`
- iGPU audio: `0f:00.1 [1002:1640]`

IOMMU groups on `aka` are clean:
```text
group 15 03:00.0 RX 7900 XT
group 16 03:00.1 RX 7900 XT HDMI/DP audio
group 27 0f:00.0 Ryzen iGPU
group 28 0f:00.1 iGPU audio
```
Current display wiring on `aka`:
```text
card0 = Ryzen iGPU, connectors disconnected
card1 = RX 7900 XT, HDMI-A-1 connected
```
So `aka` is viable for VFIO but needs host display/dummy plug moved to motherboard/iGPU, or a headless host compositor approach. Must bind only RX 7900 XT IDs to `vfio-pci`; do **not** blacklist `amdgpu` globally because iGPU needs it.

## `zao` VFIO capability check
`zao` is Dell XPS 17 9710, headless:
- CPU: Intel i9-11900H, 16 threads, VT-x.
- iGPU: Intel TigerLake-H UHD `00:02.0 [8086:9a60]`, driver `i915`.
- dGPU: NVIDIA RTX 3060 Mobile/Max-Q `01:00.0 [10de:2520]`, driver `nvidia`.
- NVIDIA audio `01:00.1 [10de:228e]`, driver `snd_hda_intel`.
- Kernel cmdline currently lacks `intel_iommu=on iommu=pt`.
- `/sys/kernel/iommu_groups` exists but has 0 groups currently.
- DMAR tables exist in kernel logs, so this likely needs kernel params and/or BIOS VT-d, not missing hardware.

`zao` topology:
```text
00:01.0-[01]--+-01:00.0 RTX 3060 Mobile
              \-01:00.1 NVIDIA Audio
```
Good signs:
- RTX 3060 has reset support:
  - `reset_file=yes`
  - `reset_method=flr bus`
  - PCI `FLReset+`
- dGPU power management shows runtime suspended / d3cold allowed.

Caveats for `zao`:
- Laptop/Optimus/muxless quirks likely.
- May need guest fake battery ACPI quirk for NVIDIA mobile driver (common reports; not proven for this machine).
- Needs guest display surface for Sunshine capture: virtual display driver, dummy plug, external/dock display wired to NVIDIA, etc.
- Dell docs suggest XPS 17 9710 with dGPU can drive external displays; Linux exposes NVIDIA DP connectors, currently disconnected.

To make `zao` VFIO-ready, next session should first add/test:
```nix
boot.kernelParams = [
  "intel_iommu=on"
  "iommu=pt"
];
```
Then reboot and re-check IOMMU groups for `01:00.0` + `01:00.1`.

## Online research summary
General VFIO performance reports:
- Well-tuned GPU passthrough often reports ~95–100% of native, with minimum overhead around 2–3% in ideal setups.
- Real games can lose more (10–30%) when CPU pinning/topology/storage/display path are poor.
- Sunshine/Moonlight inside a passthrough VM is commonly used successfully; performance mainly affected by encode/network/display, not GPU translation.
- Looking Glass with KVMFR reports low overhead; SPICE/window capture has much worse frametime/latency.
- Laptop Optimus VFIO often works but may require dummy display/virtual display and ACPI/battery quirks.

## Likely next-session plan
1. On `zao`, enable Intel IOMMU (`intel_iommu=on`, `iommu=pt`) in NixOS config.
2. Rebuild/switch/reboot `zao`.
3. Re-check `/sys/kernel/iommu_groups` and `lspci -nnk`.
4. If groups are clean, prototype binding RTX 3060 + audio to `vfio-pci`.
5. Create minimal VM with RTX 3060 passthrough.
6. Solve guest display for headless Sunshine.
7. Benchmark inside guest with GravityMark or a real game; compare to host/bare-metal expectations.
8. Test guest-side hibernation/resume with passed-through GPU.

## Current VM state warning
At end of this session, the `aka` Venus VM may still be running with `DISPLAY_BACKEND=sdl`. If starting fresh, check with:
```sh
ssh -F /dev/null aka '/tmp/venus-vm.sh status || true; pgrep -a qemu-system || true'
```
and stop with:
```sh
ssh -F /dev/null aka '/tmp/venus-vm.sh quit || true'
```
