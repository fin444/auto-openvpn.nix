{
	outputs = { self }: {
		nixosModules.auto-openvpn = import ./module.nix;
		nixosModule = self.nixosModules.auto-openvpn;
	};
}
