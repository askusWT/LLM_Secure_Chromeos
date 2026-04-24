# THIS CODE IS UNVERIFIED
# Minimal NixOS VM configuration for agent isolation
# Build: nix build --impure --expr '(import <nixpkgs/nixos> { configuration = import ./vm/configuration.nix; }).config.system.build.vm'
# Or via flake: nix build .#agent-vm
{ pkgs, ... }:
{
  # Minimal boot — no grub, tmpfs root (disk used for agent state only)
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=2G" "mode=755" ];
  };

  fileSystems."/work" = {
    device = "work";
    fsType = "9p";
    options = [ "trans=virtio" "version=9p2000.L" "msize=104857600" "nofail" ];
  };

  boot.loader.grub.enable = false;

  # Enough to run agents
  environment.systemPackages = with pkgs; [
    bubblewrap
    git
    nix
    bash
    coreutils
    curl
    jq
  ];

  # Allow nix to run inside the VM
  nix.settings.sandbox = false;

  # SSH access from host
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  # Agent user — not the Baguette user
  users.users.agent = {
    isNormalUser = true;
    extraGroups = [ ];
    openssh.authorizedKeys.keyFiles = [ ];
  };

  # No secrets here by default
  # ~/.ssh, cloud credentials, host home: never mounted

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "24.11";
}
