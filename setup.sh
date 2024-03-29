# certificates expire in 10 years
export EASYRSA_CRL_DAYS=3650
export EASYRSA_CERT_EXPIRE=3650

function genPKI() {
	echo "set_var EASYRSA_ALGO ec" > vars
	echo "set_var EASYRSA_CURVE prime256v1" >> vars

	easyrsa init-pki
	easyrsa --batch --req-cn="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)" build-ca nopass

	easyrsa --batch build-server-full "auto-openvpn" nopass
	easyrsa gen-crl

	openvpn --genkey secret /etc/auto-openvpn/tls-crypt.key
}

function genUser() {
	{
		cat "$2" # client template

		echo "<ca>"
		cat pki/ca.crt
		echo "</ca>"

		echo "<cert>"
		awk '/BEGIN/,/END CERTIFICATE/' "pki/issued/$1.crt"
		echo "</cert>"

		echo "<key>"
		cat "pki/private/$1.key"
		echo "</key>"

		echo "<tls-crypt>"
		cat tls-crypt.key
		echo "</tls-crypt>"
	} > "users/$1.ovpn"

	echo "generated user $1"
}

function revokeUser() {
	echo "revoking user $1..."

	easyrsa --batch revoke "$1"
	easyrsa gen-crl

	rm "users/$1.ovpn"
	if [[ -f /etc/auto-openvpn/ipp.txt ]]; then
		sed -i "/^$1,.*/d" /etc/auto-openvpn/ipp.txt
	fi

	echo "revoked user $1"
}

# initialize server
if [[ ! -f "/etc/auto-openvpn/vars" ]]; then
	mkdir -p /etc/auto-openvpn/users /etc/auto-openvpn/ccd /var/log/openvpn
	cd /etc/auto-openvpn
	genPKI
else
	echo "PKI already exists"
	cd /etc/auto-openvpn
fi

# revoke removed users
shopt -s nullglob # if no file matches the glob, then don't run the loop
for file in users/*.ovpn; do
	username="${file/users\//}"
	username="${username/\.ovpn/}"
	for user in "${@:2}"; do
		if [[ "$username" == "$user" ]]; then
			continue 2
		fi
	done
	revokeUser "$username"
done

# add new users
for user in "${@:2}"; do
	if [[ ! -f "users/$user.ovpn" ]]; then
		echo "adding user $user..."
		easyrsa --batch build-client-full "$user" nopass
		echo "added user $user"
	fi
	genUser "$user" "$1" # settings might have changed, so regen their config every time
done
