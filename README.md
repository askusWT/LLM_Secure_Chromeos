# agent-vm

KVM-backed NixOS VM for isolated CLI agent execution on Baguette (ChromeOS Crostini).

## Problem

Baguette (ChromeOS containerless Linux VM) lacks a practical per-agent security boundary:

- **bubblewrap** fails — ChromeOS kernel restricts user namespaces inside the Crostini guest
- **LXD/LXC** being phased out — Google AGPL policy; image remote deprecated
- **Nix dev shells** are not sandboxes — they shape the package graph, not the filesystem view

Without a boundary, every CLI agent runs as the same Unix user with full access to `~/.ssh`,
`~/Projects`, shell history, cloud credentials, and all ChromeOS-shared mounts.

## Solution

One persistent NixOS VM (KVM-backed) running inside Baguette. Per task: bubblewrap inside the
VM provides a lightweight namespace view over only the target repo.

```
Baguette (trusted dev shell)
  └── NixOS VM  [KVM boundary — always running]
        └── bwrap per task  [only target repo visible]
```

The VM gives a real kernel boundary. bubblewrap inside the VM works correctly because the VM
guest kernel has no ChromeOS namespace restrictions. No VM-per-task overhead.

## Test Results (2026-04-20)

| Check | Result |
|-------|--------|
| `/dev/kvm` present | ✓ `crw-rw----` root:kvm |
| User in kvm group | ✓ no sudo required |
| CPU virtualisation | ✓ Intel i5-1335U, VMX flags |
| `virt-host-validate` | ✓ hardware virtualisation PASS |
| KVM domain type | ✓ `domain type='kvm'` in virsh capabilities |
| Cold boot to login | ✓ **12 seconds** |
| Acceleration | ✓ KVM confirmed (not TCG software emulation) |

## Architecture

### VM layer
- NixOS guest, built from `vm/configuration.nix` via flake
- Runs persistently; agents SSH in or use `virsh console`
- `/nix/store` shared from host via virtfs (no re-download of packages)
- One qcow2 disk image; snapshot before agent run, restore after

### Task layer (inside VM)
- `bwrap` wraps each agent invocation
- Only the target repo is bind-mounted (read-write)
- `~/.ssh`, `~/Projects`, cloud credentials: absent by default
- Network: restrict to what the task actually needs

### Repo sharing
- Host repo bind-mounted into VM via virtiofs or 9p
- Agent sees `/work/<repo>` only
- Host path never exposed

## Status

- [x] KVM confirmed working — hardware acceleration, 12s boot
- [ ] Persistent VM configuration (configuration.nix)
- [ ] virtiofs repo sharing tested
- [ ] bubblewrap smoke test inside VM
- [ ] Snapshot/restore workflow
- [ ] Agent entrypoint script

## Usage (planned)

```bash
# Start persistent VM
just vm-start

# Run agent task against a repo
just agent-run ~/Projects/Scad_Playground

# Snapshot before a risky task
just vm-snapshot

# Restore if something went wrong
just vm-restore
```

## Directory Layout

```
agent-vm/
├── flake.nix              # builds NixOS VM image
├── justfile               # vm-start, vm-stop, agent-run, snapshot, restore
├── vm/
│   └── configuration.nix  # NixOS VM config (minimal, agent-ready)
├── scripts/
│   ├── agent-run          # mount repo + bwrap + invoke agent
│   └── vm-console         # attach to VM serial console
└── docs/
    ├── architecture.md    # detailed design and threat model
    └── test-results.md    # 2026-04-20 KVM viability findings
