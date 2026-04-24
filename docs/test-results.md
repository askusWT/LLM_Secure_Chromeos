# KVM Viability Test Results — 2026-04-20

## System

- Host: Baguette (ChromeOS Crostini containerless VM)
- CPU: Intel i5-1335U (13th Gen), 24 VMX-capable threads
- Kernel: Linux 6.6.99-09128-g14e87a8a9b71
- libvirt: installed via `apt install qemu-kvm libvirt-daemon-system virtinst`
- NixOS VM: built via `nix build --impure --expr '...(nixos { ... }).config.system.build.vm'`

## Baseline Checks

```
/dev/kvm:         crw-rw---- root:kvm   ← real device, not stub
user kvm group:   confirmed (gid 993)   ← no sudo required
CPU VMX flags:    24 matches            ← hardware VT-x present
```

## virt-host-validate

```
QEMU: Checking for hardware virtualization      : PASS
QEMU: Checking if device '/dev/kvm' exists      : PASS
QEMU: Checking if device '/dev/kvm' is accessible : PASS
QEMU: Checking if device '/dev/net/tun' exists  : PASS
QEMU: Checking for cgroup 'cpu' controller      : PASS
QEMU: Checking for cgroup 'memory' controller   : PASS
QEMU: Checking for cgroup 'blkio' controller    : PASS
```

Warnings (non-blocking):
- `vhost_net` module not loaded (network perf optimisation only)
- `devices` cgroup not enabled (minor)
- No IOMMU/DMAR (expected inside a VM; PCI passthrough not needed)

## virsh capabilities

```xml
<domain type='qemu'/>
<domain type='kvm'/>   ← KVM domain type available
```

## Boot Timing

Test: cold boot of minimal NixOS VM (no prior disk image)

```
start:     14:57:26
login:     14:57:38
elapsed:   12 seconds
```

Acceleration confirmed: QEMU process running with `accel=kvm:tcg` and KVM path taken
(12s is consistent with KVM; TCG software emulation would take 90–180s for the same image).

## LXD/LXC Status (websearch finding)

- Google AGPL policy prevents long-term LXD support on ChromeOS
- `images:` remote being phased out for Chromebook LXD version
- Incus cannot replace LXD without developer mode (termina VM is read-only)
- **Conclusion: LXD/LXC fallback is not viable long-term**

## Verdict

**KVM has legs.** Both function and performance criteria pass:

- ✓ KVM acceleration works (not software emulation)
- ✓ 12s cold boot is tolerable; persistent VM = 0s startup cost
- ✓ virtiofs/9p available for repo-only sharing (default VM script already uses virtfs)
- ✓ Snapshots via qcow2 CoW (not yet timed but near-instant in principle)
- ✓ No root friction — user in kvm group

## Remaining Work

- [ ] virtiofs repo sharing smoke test (mount one project, not full home)
- [ ] bubblewrap inside VM (expected to work; test needed)
- [ ] Snapshot create/restore timing
- [ ] Persistent VM configuration (systemd autostart, SSH access)
- [ ] Agent entrypoint script
