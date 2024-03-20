{ config, lib, pkgs, ... }:
let cfg = config.services.auto-openvpn;
in {
	###### interface

	options.services.auto-openvpn = with lib; {
		enable = mkEnableOption "Enable auto-openvpn.";

		enableIPv6 = mkEnableOption "Enable IPv6 support.";

		interface = mkOption {
			type = types.str;
			description = "The network interface used by your server.";
		};

		address = mkOption {
			type = types.str;
			description = "The public address of your server. Can be an IP or FQDN. Warning: changing this will require re-issuing configs to all users!";
		};

		port = mkOption {
			type = types.port;
			default = 1194;
			description = "The port the server should listen on. Warning: changing this will require re-issuing configs to all users!";
		};

		dns = mkOption {
			type = types.listOf types.str;
			default = [ "9.9.9.9" "149.112.112.112" ];
			description = "DNS servers used by connected clients. Defaults to Quad9.";
		};

		users = mkOption {
			type = types.listOf (types.strMatching "^[a-zA-Z0-9_-]+$");
			default = [];
			description = "List of users to generate configs for. Removing someone from this list will permanently revoke access to their config, if you add them back later they will need to get the new config.";
		};
	};

	###### implementation

	config = let
		setupScript = pkgs.writeShellApplication {
			name = "auto-openvpn-setup.sh";
			runtimeInputs = with pkgs; [ easyrsa gawk openvpn ];
			text = builtins.readFile ./setup.sh;
		};
		clientTemplate = pkgs.writeText "auto-openvpn-client-template.txt" ''
			client
			remote ${cfg.address} ${toString cfg.port}
			proto udp
			dev tun
			resolv-retry infinite
			nobind
			persist-key
			persist-tun
			remote-cert-tls server
			verify-x509-name auto-openvpn name
			auth SHA256
			auth-nocache
			cipher AES-128-GCM
			tls-client
			tls-version-min 1.2
			tls-cipher TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256
			ignore-unknown-option block-outside-dns
			setenv opt block-outside-dns
			verb 3
		'';
	in lib.mkIf cfg.enable {
		networking.nat = {
			enable = true;
			enableIPv6 = cfg.enableIPv6;
			externalInterface = cfg.interface;
			internalInterfaces = [ "tun0" ];
		};

		networking.firewall.allowedUDPPorts = [ cfg.port ];

		services.openvpn.servers.auto.config = ''
			port ${toString cfg.port}
			proto udp
			dev tun0
			persist-key
			persist-tun
			keepalive 10 120
			topology subnet
			server 10.8.0.0 255.255.255.0
			ifconfig-pool-persist /etc/auto-openvpn/ipp.txt
			push "redirect-gateway def1 bypass-dhcp"
			dh none
			ecdh-curve prime256v1
			tls-crypt /etc/auto-openvpn/tls-crypt.key
			crl-verify /etc/auto-openvpn/pki/crl.pem
			ca /etc/auto-openvpn/pki/ca.crt
			cert /etc/auto-openvpn/pki/issued/auto-openvpn.crt
			key /etc/auto-openvpn/pki/private/auto-openvpn.key
			auth SHA256
			cipher AES-128-GCM
			ncp-ciphers AES-128-GCM
			tls-server
			tls-version-min 1.2
			tls-cipher TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256
			client-config-dir /etc/auto-openvpn/ccd
			status /var/log/openvpn/status.log
			verb 3
		'' + lib.optionalString cfg.enableIPv6 ''
			server-ipv6 fd42:42:42:42::/112
			tun-ipv6
			push tun-ipv6
			push "route-ipv6 2000::/3"
			push "redirect-gateway ipv6"
		'' + lib.concatMapStrings (s: "push \"dhcp-option DNS " + s + "\"\n") cfg.dns;

		systemd.services.auto-openvpn-setup = {
			description = "Set up auto-openvpn";
			requiredBy = [ "openvpn-auto.service" ];
			before = [ "openvpn-auto.service" ];
			serviceConfig = {
				ExecStart = "${setupScript}/bin/auto-openvpn-setup.sh ${clientTemplate} ${lib.strings.concatStringsSep " " cfg.users}";
				Type = "oneshot";
			};
		};
	};
}
