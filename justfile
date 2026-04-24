# agent-vm justfile
# Requires: qemu-kvm libvirt-daemon-system virtinst (apt)
#           nix (for building the VM image)

VM_NAME := "agent-vm"
VM_IMAGE := env_var_or_default("VM_IMAGE", "~/.local/share/agent-vm/agent-vm.qcow2")

# Build the NixOS VM image
build:
    nix build --impure --expr '
      (builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux.nixos {
        imports = [ ./vm/configuration.nix ];
      }' -A config.system.build.vm

# Start the persistent VM (background)
vm-start:
    #!/usr/bin/env bash
    mkdir -p ~/.local/share/agent-vm
    NIX_DISK_IMAGE={{VM_IMAGE}} \
    QEMU_OPTS='-nographic -daemonize -pidfile /tmp/agent-vm.pid' \
    ./result/bin/run-nixos-vm
    echo "VM started (PID $(cat /tmp/agent-vm.pid))"

# Stop the VM
vm-stop:
    virsh destroy {{VM_NAME}} 2>/dev/null || pkill -F /tmp/agent-vm.pid

# Open serial console
vm-console:
    virsh console {{VM_NAME}}

# Snapshot before agent run
vm-snapshot NAME="pre-run":
    virsh snapshot-create-as {{VM_NAME}} "{{NAME}}-$(date +%Y%m%d-%H%M%S)"

# List snapshots
vm-snapshots:
    virsh snapshot-list {{VM_NAME}}

# Restore to a snapshot
vm-restore SNAPSHOT:
    virsh snapshot-revert {{VM_NAME}} {{SNAPSHOT}}

# Run an agent task against a repo
# Usage: just agent-run ~/Projects/Scad_Playground "claude -p 'task description'"
agent-run REPO CMD:
    scripts/agent-run {{REPO}} {{CMD}}

# Check VM status
status:
    #!/usr/bin/env bash
    if [ -f /tmp/agent-vm.pid ] && kill -0 "$(cat /tmp/agent-vm.pid)" 2>/dev/null; then
        echo "VM running (PID $(cat /tmp/agent-vm.pid))"
    else
        echo "VM not running"
    fi
