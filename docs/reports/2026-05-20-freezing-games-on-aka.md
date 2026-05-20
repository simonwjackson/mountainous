# Freezing Games on `aka` — Options, Trade-offs, and Recommendation

**Goal:** Be able to pause/freeze *any* game on `aka` such that it can be resumed later — ideally even across a host reboot.

**Host context (`hosts/aka/`):**
- CPU: AMD (`kvm-amd`, microcode updates enabled)
- GPU: AMD discrete (`amdgpu` driver)
- Storage: Samsung NVMe (7.6 TB enterprise SSD)
- OS: NixOS, Sway/Wayland session, Sunshine + Korri stream server
- Already has: `hibernation.enable = true`, swap partition, `suspend-then-hibernate` on power key, `HibernateDelaySec = 2h`
- Virtualization: KVM-AMD enabled, no current GPU passthrough

The "freeze a game" problem on PC has no single clean answer like console Quick Resume. There are five distinct approaches, each with a different ceiling. I'll cover them from simplest/cheapest to most ambitious.

---

## Option 1 — Whole-system suspend / suspend-then-hibernate *(already configured)*

This is what the Steam Deck actually does. "Quick Resume" on Steam Deck is **system-level S3 suspend (to RAM)**, and the OLED's hibernation is **S4 (to disk)**. The game is not specially saved; the entire kernel + game + GPU driver state goes to RAM (or to swap), and the GPU resumes through standard `amdgpu` suspend/resume hooks.

You already have this on `aka`:

```nix
systemd.sleep.settings.Sleep = {
  AllowSuspend = true;
  AllowHibernation = true;
  AllowSuspendThenHibernate = true;
  HibernateDelaySec = "2h";
};
services.logind.settings.Login = {
  HandlePowerKey = "suspend-then-hibernate";
};
```

**What it gives you**
- Freeze any game, including anti-cheat-laden Windows games via Proton.
- Survives reboots (the hibernate part writes RAM → swap → power off, resume restores it).
- Zero custom tooling.

**Trade-offs**
- Freezes the **whole machine**. While the game is "paused," `aka` cannot serve Sunshine, Korri, or anything else.
- One game at a time. You cannot freeze Game A and then play Game B.
- WoL works (`networking.interfaces.eno1.wakeOnLan.enable = true` is already set), so you can wake from another room.
- `amdgpu` hibernate/resume on desktop discrete cards is *usually* solid, but some titles (especially anti-cheat'd ones, online sessions, or games with hardware-timed DRM checks) will disconnect / lose session / require restart anyway. Single-player offline titles fare best.

**Verdict:** This is the baseline. It already works. Everything below is "what if I want more than one frozen game" or "what if I want the host to keep doing other work."

---

## Option 2 — Pause a single process with `SIGSTOP` + let swap absorb it

Cheapest "per-game" option. `kill -STOP <pid>` halts a process's execution. It still occupies RAM, but the kernel will gladly swap idle pages out as memory pressure rises. Resume with `kill -CONT <pid>`.

**What it gives you**
- True per-game pause without touching anything else.
- You can pause Game A, launch Game B, swap A's memory out under pressure.
- Zero hardware-specific gotchas, no kernel patches.

**Trade-offs**
- **Does not survive reboot.** Process state is in RAM/swap, all owned by a live kernel.
- GPU state stays bound to a paused process. The display driver still considers the GL/Vulkan context "alive." Multi-buffer/swapchain ownership can confuse a compositor; you'll likely want to minimize/hide the window first.
- Anti-cheat (e.g. EAC, BattlEye) and online sessions will disconnect after some seconds-to-minutes of unresponsiveness.
- Audio devices may glitch on resume; usually self-heals.

**Verdict:** Useful as "alt-tab on steroids" while the host is running. Will not save you across `reboot`. Almost no effort to implement.

---

## Option 3 — CRIU (Checkpoint/Restore In Userspace)

This is the closest thing Linux has to a true "savestate for a process." CRIU walks `/proc/<pid>`, dumps memory, file descriptors, namespaces, etc. to disk, and can re-create the process later — even after a reboot.

**Reality check for games on AMD GPU:**

- CRIU's **AMDGPU plugin exists** and is real ([`criu/plugins/amdgpu`](https://github.com/checkpoint-restore/criu/tree/criu-dev/plugins/amdgpu)), with ongoing work — including the gCROP fast-restore method published at SoCC'24 ([LWN 1024747](https://lwn.net/Articles/1024747/)).
- It is **designed for ROCm compute workloads** (TensorFlow, PyTorch, AI training migration across nodes). Not games.
- It checkpoints the **KFD compute device** (`/dev/kfd`), not the **render device** (`/dev/dri/renderD*`) that OpenGL/Vulkan games use.
- Games hold many things CRIU finds awkward: Wayland/X11 sockets to a *running* compositor, pulse/pipewire connections, Steam IPC, Vulkan swapchains tied to a display.
- Per the CRIU project itself ([issue #2326](https://github.com/checkpoint-restore/criu/issues/2326)): general 3D GPU workloads are not supported. Only headless / compute-only paths are.

**What it gives you (in theory)**
- Per-process checkpoint to a file. Survives reboot.

**Trade-offs (in practice for games)**
- Game-class workloads (DXVK/VKD3D Vulkan via Proton, native OpenGL, etc.) will almost certainly not round-trip cleanly.
- Display server reconnection alone is a research problem; an X11/Wayland client's resources are held by the server, which restarts on reboot.
- Active development is upstream-pulled toward ML, not gaming. There's no community of users routinely CRIU'ing Steam games.

**Verdict:** Interesting to know about. Not a viable answer for "freeze any game" in 2026. Worth a 30-minute experiment with a trivial native OpenGL toy. Not worth building infrastructure around.

---

## Option 4 — Run the game in a VM and use VM save/restore (the "amazing worst case" you asked about)

This is the most promising path **if you genuinely want multiple frozen game states and want them to survive a host reboot.** The VM is the freezer.

### 4a. VM with **virtio-gpu Venus** (Vulkan via native context)

A modern guest can get real Vulkan acceleration *without* a passed-through physical GPU using virtio-gpu + Venus (Vulkan-on-virtio). On the host this looks like a normal QEMU process. That means **`virsh save` / `virsh managedsave` / `savevm` works**, and `virsh save` produces a complete RAM+CPU image you can `virsh restore` later — including across host reboots, because the image is on disk.

- ✅ Per-game freezing: one VM per game, save/restore independently.
- ✅ Survives reboot.
- ✅ Host stays usable: while a VM is saved (`managedsave`), it consumes only disk, not RAM or GPU.
- ⚠️ Performance: Venus is good for many titles, but won't match native. Anti-cheat / DX12 / heavy AAA may be unhappy.
- ⚠️ Linux-only guest is easiest; Windows Venus story is weaker.
- ⚠️ Audio routing through the VM adds latency, especially for Sunshine streaming.

### 4b. VM with **VFIO GPU passthrough** (the powerful, painful path)

Pass `aka`'s `amdgpu` (or a second GPU) to the guest. Game runs at native speed. But:

- ❌ **`virsh save` / `savevm` fails for VMs with passed-through PCI devices.** QEMU cannot serialize device state for a passthrough GPU — it doesn't own that state, the physical card does ([VFIO subreddit confirmation](https://www.reddit.com/r/VFIO/comments/h0tctg/error_trying_to_save_vm_state_in_qemu_using_pci/)). Trying produces an error or a corrupted resume.
- ✅ **`virsh dompmsuspend --target disk <vm>`** *does* work — it triggers an **S4 hibernate inside the guest**, the guest OS writes its own RAM to its own swap, then powers off. On `virsh start`, the guest resumes from its hibernate image. This is the supported pattern. ([r/VFIO 568mmt](https://www.reddit.com/r/VFIO/comments/568mmt/saving_vm_state_with_gpu_passthrough/), [r/VFIO erys86](https://www.reddit.com/r/VFIO/comments/erys86/hibernating_a_vm_with_devices_passed_through/)).
- ⚠️ Requires a guest configured for hibernation (swap, kernel cmdline, drivers, etc.).
- ⚠️ AMD-specific: **"AMD reset bug"** historically affects some Radeon families (Polaris, Vega, some Navi) where the GPU won't re-initialize cleanly after a VM stop. Workarounds exist (`vendor-reset` kernel module, hookscripts). RDNA 2/3 are generally fine but verify per-card.
- ⚠️ Requires either a second GPU dedicated to the VM, or careful single-GPU-passthrough scripts (and you lose your host display while the VM runs). Single-GPU passthrough is hostile to Sunshine/Korri running on the host at the same time.

### 4c. VM with **virgl/virtio-gpu (OpenGL only)**

Lower-friction than Venus, but most modern Windows games via Proton want Vulkan. OK for older or native Linux titles. Same save/restore story as 4a — host owns all state, `virsh save` works.

**Verdict on Option 4:**
The most realistic "freeze multiple games across reboots" answer on `aka` is:

- **One VM per game (or per game profile)**, with **virtio-gpu Venus** for Linux-native or Proton titles that tolerate it. `virsh managedsave` per VM.
- For demanding titles, **VFIO passthrough VM** using `dompmsuspend disk` instead of `virsh save`. Slower freeze/thaw (guest writes RAM to its own disk) but it works.

---

## Option 5 — Streaming-layer pause (Sunshine / Moonlight + per-session lifecycle)

This doesn't solve "freeze the game" — it solves **"is the game still running while nobody is watching?"**. Worth mentioning because you already run Sunshine + Korri:

- A Sunshine "app" can launch the game; when the stream ends, Sunshine can leave it running or kill it.
- If you leave the game running on the host, Option 2 (`SIGSTOP`) gives you on-demand pause without disturbing other streams or the host.
- This composes well with Option 4: stream the **guest's** display via Sunshine running inside the guest, and freeze the guest itself.

---

## Side-by-side

| Option | Freeze any game? | Survives reboot? | Per-game? | Host stays useful? | Effort |
|---|---|---|---|---|---|
| 1. System suspend-then-hibernate *(have it)* | ✅ | ✅ | ❌ one at a time | ❌ host paused too | none |
| 2. `SIGSTOP` + swap | ✅ | ❌ | ✅ | ✅ | trivial script |
| 3. CRIU | ⚠️ headless/compute only | ✅ in theory | ✅ | ✅ | research, likely dead end for games |
| 4a. VM + virtio-gpu Venus + `virsh save` | ⚠️ Vulkan-capable titles | ✅ | ✅ | ✅ | medium |
| 4b. VM + VFIO + `dompmsuspend disk` | ✅ at native perf | ✅ | ✅ | ⚠️ depends on GPU layout | high |
| 4c. VM + virgl (GL only) | ⚠️ older / GL titles | ✅ | ✅ | ✅ | medium |
| 5. Sunshine lifecycle + Option 2 | ✅ | ❌ | ✅ | ✅ | low |

---

## Recommendation for `aka`

Given the existing setup (single AMD GPU, Sunshine + Korri streaming, NixOS, hibernation already on, no second GPU):

1. **Already done — keep `suspend-then-hibernate`.** It's the universal fallback. Worst case for any title is "press power, walk away, come back later, press power."

2. **Add a `SIGSTOP`-based "pause this game" hotkey** for in-session per-game freezing without taking the whole host down. Bind it through `evdev-hotkey` / Sway to a script that minimizes the focused window and `SIGSTOP`s its PID tree. Resume = `SIGCONT`. This costs ~30 lines of shell. Pairs naturally with Sunshine: end the stream, leave the process paused, resume next time you connect.

3. **Skip CRIU for games.** Revisit only if `criu-amdgpu-plugin` ever advertises render-device (`/dev/dri/renderD*`) support, not just KFD/compute. Today it's the wrong tool.

4. **If you want true per-game cold-freeze across reboots**, build it as **Option 4a (Venus VM) for everything that runs in it**, and reach for **4b (VFIO + `dompmsuspend disk`)** only for titles that need native GPU. This is real work — a NixOS feature module (`features/game-vm/`) wiring a libvirt domain, a Wayland-friendly Venus stack, and a small CLI to `freeze`/`thaw <vm>`. The "freeze" command is `virsh managedsave`; the "thaw" is `virsh start`.
   - For VFIO you'd also need: a second GPU (cleanest), or single-GPU-passthrough scripting (ugly with Sunshine on the host), plus `vendor-reset` if your card's family needs it. Verify the specific AMD GPU model in `aka` before committing.

5. **Don't try to make `aka` do everything at once.** A single-GPU host that also serves Sunshine cannot simultaneously be a VFIO passthrough target without juggling. If `aka` is primarily a stream host, a Venus VM is the right ceiling. If `aka` is primarily a private gaming station that you stream from, the VFIO route makes sense — but plan around a second GPU.

---

## Concrete next steps (cheap → ambitious)

- ☐ **30 min:** Add a `pause-foreground-game` Sway keybinding that `SIGSTOP`s the focused window's PID tree (and `SIGCONT` to resume). Document the limitation: in-session only.
- ☐ **1–2 hr:** Verify the current `suspend-then-hibernate` path actually round-trips a running Proton title cleanly on `aka`. Record what breaks (audio device re-enumeration, controller rebind, anti-cheat session timeout, etc.) in `docs/runbooks/`.
- ☐ **1 day:** Prototype Option 4a — a single Linux guest VM with virtio-gpu Venus, run a Vulkan title (Proton or native), `virsh managedsave` mid-game, `virsh start` after a host reboot, confirm the game is where you left it. This is the cleanest "freeze any game across reboot, host still works" path.
- ☐ **Multi-day:** Only if 4a's performance ceiling is unacceptable for the titles you actually care about — investigate Option 4b (VFIO + `dompmsuspend disk`), starting with confirming the exact GPU model on `aka` and whether its reset behavior is clean on RDNA 2/3 or needs `vendor-reset`.

---

## References

- CRIU AMDGPU plugin — <https://github.com/checkpoint-restore/criu/tree/criu-dev/plugins/amdgpu>
- LWN — *A parallel path for GPU restore in CRIU* (gCROP, SoCC'24) — <https://lwn.net/Articles/1024747/>
- CRIU upstream — *Stateless GPU workloads* issue confirming general-3D not supported — <https://github.com/checkpoint-restore/criu/issues/2326>
- VFIO Reddit — *Saving VM state with GPU passthrough* (use `dompmsuspend disk`) — <https://www.reddit.com/r/VFIO/comments/568mmt/saving_vm_state_with_gpu_passthrough/>
- VFIO Reddit — *Error saving VM state with PCI passthrough* (why `virsh save` won't work for VFIO) — <https://www.reddit.com/r/VFIO/comments/h0tctg/>
- AMD GPU reset bug + `vendor-reset` — <https://github.com/gnif/vendor-reset>
- Steam Deck "Quick Resume" = system S3/S4 — <https://github.com/xXJSONDeruloXx/hibernado>
- libTAS (process-level savestates for TAS, niche) — <https://github.com/clementgallet/libTAS>
- "Faux Quick Resume for PC" pattern (hotkey → hibernate) — <https://www.reddit.com/r/pcmasterrace/comments/111ec04/faux_quick_resume_for_pc_guide/>
