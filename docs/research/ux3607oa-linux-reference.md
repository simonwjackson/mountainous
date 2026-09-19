# ASUS Zenbook A16 UX3607OA Linux reference

## Scope

This note records the closest reproducible Linux reference for myoko before another kernel is built or booted.

## Reference

| Item | Value |
|---|---|
| Repository | <https://github.com/jc372/A16UbuntuBuild> |
| Repository commit reviewed | `3de6f0a4921641dde5fae0e912725821b7396c55` |
| Commit date | 2026-09-17 |
| Machine | ASUS Zenbook A16 UX3607OA |
| Running kernel reported | `7.3.0-rc3-next-20260914` |
| Linux-next commit reported | `1a1de54f7369cd2b5bac0f265910e60ad3a6b4c3` |
| Firmware description | Device tree with `acpi=off` |
| Panel | Samsung `ATNA60HR07-0`, 2880x1800, 30–120 Hz |

This is a community report from the owner of the same model. It is not an upstream test result or an ASUS support statement.

## Reported working state

The reference reports these items working:

- Internal panel at 2880x1800 with 120 Hz and 60 Hz modes.
- Backlight control through `dp_aux_backlight`.
- Internal keyboard, touchpad, touchscreen, and stylus.
- Wi-Fi and Bluetooth after board data, firmware, and device-tree changes.
- Battery reporting and charge control.
- HDMI.
- Audio playback, with microphone capture still incomplete.

The kernel binds the gen8 Adreno GPU and creates `/dev/dri/renderD128`. Mesa freedreno does not support chip ID `0x18444070041`, so rendering falls back to software. A bound kernel driver does not mean accelerated graphics work.

## Display requirements

The working reference carries four display patches:

| Patch | Purpose |
|---|---|
| Bjorn Andersson v8 eDP PHY patch 1/2 | Split PHY power-on sequencing by PHY version. |
| Bjorn Andersson v8 eDP PHY patch 2/2 | Program the Glymur v8 PHY by link rate and lane count. |
| Jesse Casco `PUSH_IDLE` guard | Do not push idle when link enable failed. This avoids a reported TrustZone-triggered SoC reset. |
| UX3607OA HBR3 rate override | Use 8.1 Gbit/s HBR3 because this panel fails equalization at its advertised 5.4 Gbit/s HBR2 rate. |

The two Bjorn Andersson patch bodies in this repository match the reference patch bodies. Their mail headers differ.

The final same-model report does **not** confirm that the posted PHY series alone makes this panel work at HBR2. It says the series still fails for this panel's four-lane HBR2 case and carries the HBR3 override. This corrects the earlier claim in `docs/decisions/glymur.md`.

The reference reports this HBR2 failure sequence:

1. Clock recovery succeeds on all four lanes.
2. Channel equalization times out with `-110`.
3. A later disable path sends `PUSH_IDLE` although the link never became active.
4. Glymur can then reset silently through a TrustZone SOCCP/ADSP force-stop.

## Comparison with the two myoko probes

| Property | Known-good probe | Failed GPUCC probe | Working same-model reference |
|---|---:|---:|---:|
| `CONFIG_CLK_GLYMUR_GPUCC` | Not set | Built in | Required; reference build supports built-in or matching module use |
| v8 eDP PHY patches | Yes | Yes | Yes |
| Failed-link `PUSH_IDLE` guard | No | No | Yes |
| HBR3 override | No | No | Yes |
| MSM can bind | No | Expected | Yes |
| SSH reached | Yes | No | Yes |
| Internal panel through MSM | No | No | Yes |

**Inferred, not proven:** the failed probe enabled enough of the MSM dependency chain to attempt eDP. HBR2 training then failed, and the missing `PUSH_IDLE` guard allowed the silent reset described by the same-model report. The failed boot left no log, so this remains a hypothesis until the next probe writes its kernel log to the USB.

## Recovery USB audit

The aborted `/tmp/deploy-myoko-probe-variant` operation did not leave an unknown boot image active. The post-attempt runtime capture in `/persist/backups/myoko-platform-S7X8NX0L344749-2026-09-18/myoko-known-good-runtime.tar.gz` records:

| USB file | SHA-256 | State |
|---|---|---|
| `BOOTAA64.EFI` | `adaa51ec60135d38fee4a8170ae6875712249bee873f355192c2d72006175191` | Verified known-good |
| `BOOTAA64.EFI.previous` | `adaa51ec60135d38fee4a8170ae6875712249bee873f355192c2d72006175191` | Verified known-good |
| `BOOTAA64.EFI.failed-gpucc` | `36e9905d7af36bea13eccc5615d5ac330931df19b695adae1e9d4e055384501a` | Retained failed probe |

The deployment helper writes `BOOTAA64.EFI.new`, verifies it, rotates the current file to `.previous`, and then renames the new file into place. The later capture checked the actual USB files, not only the local source. Recovery therefore remains intact.

## Complete reference-patch test

The first complete reference-patch UKI had SHA-256 `a4d361ee170f0c4b29a37f682217e116a2c0a03a0de6f45d608e256d5ea0b09e`. It passed build, kernel configuration, module resolution, UKI section, DTB, initrd, firmware, and command-line checks.

Runtime still failed. The panel stayed black and SSH never opened. The RTL8156 interface answered ICMP at `192.168.1.239`, so the machine did not reset. No `myoko-display-*.log` file appeared on the USB. The system therefore stopped before the multi-user logging service created its file.

The active USB image was restored to the verified recovery hash. The failed image remains as `BOOTAA64.EFI.failed-reference`. The internal NVMe was not written.

## Safe next probe

The next probe must:

1. Keep the verified known-good UKI and its matching kernel and modules unchanged as recovery artifacts. `scripts/stage-myoko-probe` verifies the artifact, creates a fixed `BOOTAA64.EFI.recovery` copy from the known-good hash, rotates `.previous`, and does not reboot.
2. Build GPUCC, GXCLKCTL, and MSM as matching modules.
3. Block their OF aliases so early boot remains aligned with the known-good probe.
4. Start the synchronous USB log before loading `gpucc-glymur`, `gxclkctl-kaanapali`, and `msm` by name.
5. Preserve matching kernel and module outputs as one test unit.
6. Boot once, then inspect the USB log before any second boot.

A successful test needs all of these results:

- SSH starts.
- The machine does not reset during MSM load or DPMS disable.
- `/sys/class/drm/*eDP*` reports connected.
- Both 2880x1800 modes are present.
- `dp_aux_backlight` exists.
- Keyboard, touchpad, touchscreen, Ethernet, and CPU frequency policies still work.
- The five-minute OLED blanking command succeeds under the Lua Hyprland configuration.

## Sources

- Main reference: <https://github.com/jc372/A16UbuntuBuild/tree/3de6f0a4921641dde5fae0e912725821b7396c55>
- Display report: <https://github.com/jc372/A16UbuntuBuild/blob/3de6f0a4921641dde5fae0e912725821b7396c55/docs/display-edp.md>
- GPU report: <https://github.com/jc372/A16UbuntuBuild/blob/3de6f0a4921641dde5fae0e912725821b7396c55/docs/gpu-adreno.md>
- Boot modes: <https://github.com/jc372/A16UbuntuBuild/blob/3de6f0a4921641dde5fae0e912725821b7396c55/docs/boot-options.md>
- Build and module matching: <https://github.com/jc372/A16UbuntuBuild/blob/3de6f0a4921641dde5fae0e912725821b7396c55/docs/build.md>
- `PUSH_IDLE` patch provenance: <https://patchew.org/linux/20260808171325.133041-1-jesse.casco@gmail.com/>
- Posted v8 PHY series archive: <https://lore.kernel.org/all/20260622-glymur-edp-phy-v1-0-814b45089ac9@oss.qualcomm.com/>
