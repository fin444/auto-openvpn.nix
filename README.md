# auto-openvpn.nix

Automatic configuration, certificate generation, and user management for OpenVPN on NixOS so you don't have to.

> [!IMPORTANT]
> I am not an expert on security or OpenVPN. I don't believe there are security flaws, but use at your own risk. All settings in this module are based on [openvpn-install](https://github.com/angristan/openvpn-install).

## Usage

### Basic Example

```nix
{
  services.auto-openvpn = {
    enable = true;
    interface = "enp1s0"; # your server's network interface
    address = "example.com"; # FQDN or IP
    users = [ "fin444" ];
  };
}
```

User configs will be generated in `/etc/auto-openvpn/users/`.

More information about settings can be found in the [module itself](https://github.com/fin444/auto-openvpn.nix/blob/main/module.nix).

> [!WARNING]
> Changing the `address` and `port` options will require you to re-issue configs to all users.
>
> Removing a user from `users` will permanently invalidate their config, if you put them back in they will need a new copy.

### Flake Input
```nix
{
  inputs.auto-openvpn.url = "github:fin444/auto-openvpn.nix";

  outputs = { self, nixpkgs, auto-openvpn, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        auto-openvpn.nixosModules.auto-openvpn
      ];
    };
}
```

### Traditional Import

```nix
{
  imports = [ "${builtins.fetchTarball "https://github.com/fin444/auto-openvpn.nix/archive/master.tar.gz"}/module.nix" ];
}
```

### Impermanence

In order to work between restarts, `/etc/auto-openvpn` must be persisted.
