# Installation

## From Source

Clone the repository, build, and install:

```bash
git clone https://github.com/your-org/touchstone.git
cd touchstone
make install
```

`make install` places the following tools on your PATH:

| Tool | Purpose |
|------|---------|
| `ts-sudo` | Privileged local command execution with consent |
| `ts-ssh` | Remote command execution over SSH with consent |
| `ts-scp` | Secure file copy with consent |
| `ts-sftp` | SFTP session with consent |
| `ts-run` | General command execution with consent (interactive mode) |

By default, binaries install to `/usr/local/bin` and configuration to `/etc/touchstone/`. Override with:

```bash
make install PREFIX=/opt/touchstone
```

### Verify the Installation

Run the built-in checks:

```bash
make check
```

This verifies:

- All binaries are on PATH
- WezTerm is reachable and supports the required multiplexing API
- PAM is configured correctly
- FIDO2 key is enrolled (if hardware auth is enabled)

Then confirm basic operation:

```bash
ts-sudo whoami
```

You should see the three-pane WezTerm window appear. Authenticate, and the command should return `root`.

---

## NixOS Flake

Add Touchstone to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    touchstone.url = "github:your-org/touchstone";
  };

  outputs = { self, nixpkgs, touchstone, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        touchstone.nixosModules.default
        {
          services.touchstone = {
            enable = true;
            fido2.enable = true;  # optional, enables YubiKey requirement
          };
        }
      ];
    };
  };
}
```

Rebuild your system:

```bash
sudo nixos-rebuild switch --flake .#myhost
```

The flake handles WezTerm, PAM configuration, FIDO2 libraries, and PATH setup.

---

## Uninstall

### From Source

```bash
cd touchstone
make uninstall
```

This removes all installed binaries and the `/etc/touchstone/` configuration directory. User-level configuration in `~/.config/touchstone/` is preserved -- delete it manually if desired.

### NixOS

Remove the Touchstone module from your NixOS configuration and rebuild:

```bash
sudo nixos-rebuild switch --flake .#myhost
```
