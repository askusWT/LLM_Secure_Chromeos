# Architecture: KVM Agent Isolation on Baguette

## Threat Model

CLI agents running on a single Linux user account can:

1. Read unrelated project files, dotfiles, shell history
2. Access `~/.ssh`, `~/.config/gh`, cloud CLIs, API tokens, Nix caches
3. Make unrestricted network calls
4. Modify repo state outside the intended workspace
5. Persist through shell hooks, Git hooks, language package scripts
6. Laterally move across all projects under the same Unix user

The ChromeOS VM boundary protects ChromeOS from Baguette. It does not protect projects and
credentials inside Baguette from an agent running in the same Linux environment.

## Why KVM, Not Process Sandboxing

| Approach | Status | Reason |
|----------|--------|--------|
| bubblewrap | Broken in Baguette | ChromeOS kernel restricts user namespace creation in the Crostini guest |
| LXD/LXC | Deprecated | Google AGPL policy; images remote being phased out |
| systemd hardening | Belt, not lock | Same user workflow controls the units and home directory |
| Nix dev shells | Not a sandbox | Shapes package graph, not filesystem or process view |
| KVM nested VM | **Working** | `/dev/kvm` exposed in Baguette guest; hardware acceleration confirmed |

## Isolation Layers

### Layer 1: KVM VM boundary
- NixOS guest runs as a separate kernel under QEMU/KVM
- Separate filesystem, separate memory, explicit virtual disks
- No implicit access to Baguette home directory
- Destroy/recreate lifecycle is obvious and scriptable
- `/nix/store` shared read-only from host (performance optimisation, not a secret store)

### Layer 2: bubblewrap per task (inside VM)
- Works correctly inside the VM guest kernel (no ChromeOS namespace restrictions)
- Per-agent invocation gets a minimal filesystem view
- Only the target repo bind-mounted read-write
- tmpfs for everything else

### Layer 3: systemd inside VM (defense in depth)
- Run agent under a hardened unit: `DynamicUser`, `ProtectHome`, `PrivateTmp`, `NoNewPrivileges`
- Treat as belt, not primary boundary

## Repo Sharing

Preferred: **virtiofs** (kernel-native, low latency, no protocol overhead)
Fallback: **9p** (slower but always available)
Emergency: **sshfs** (works without kernel module support)

Host path: `~/Projects/<repo>` (read-only or read-write as needed)
Guest path: `/work/<repo>` (only path visible to agent)

The Baguette home directory is never mounted into the VM.

## Snapshot Workflow

```
before agent run:
  virsh snapshot-create-as agent-vm pre-run-$(date +%Y%m%d-%H%M%S)

after agent run (clean):
  # leave snapshot, or delete it:
  virsh snapshot-delete agent-vm pre-run-...

after agent run (damage):
  virsh snapshot-revert agent-vm pre-run-...
```

qcow2 snapshots are cheap (copy-on-write). Snapshot creation is near-instant.

## Network Model

Default: NAT via libvirt (VM can reach internet, host cannot be reached from VM)
Restricted: libvirt network with nftables/iptables allow-list
Isolated: `--network none` for tasks that need no network

## Performance Envelope (tested 2026-04-20)

- Cold boot to NixOS login: **12 seconds** (KVM-accelerated, i5-1335U)
- Expected persistent VM SSH latency: negligible (VM stays running)
- Snapshot create: near-instant (qcow2 CoW)
- Snapshot restore: ~2-5s estimate (not yet tested)

## Security Properties

| Property | KVM VM | bubblewrap-in-VM |
|----------|--------|-----------------|
| Separate kernel | ✓ | — |
| Separate filesystem | ✓ | ✓ |
| No home dir access | ✓ | ✓ |
| No credential access | ✓ | ✓ |
| Network control | ✓ (libvirt) | partial |
| Snapshot/rollback | ✓ | — |
| Startup cost | 12s cold / 0s persistent | <1s |
| Per-task cost | 0s (persistent VM) | <1s |
