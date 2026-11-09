#!/usr/bin/env bash
# Simulated Wi-Fi for the test VM, run by `test/vm wifi` as the takumi user. VM only; nothing here ships.
# mac80211_hwsim gives six radios. Five move into their own network namespace, a router of their own,
# and become access points (hostapd, dnsmasq) with internet through the VM's cable. The sixth stays with
# NetworkManager, so the desktop sees five real networks to join:
#   Takumi Home (WPA2) · Corner Café (open) · Attic: 5G (WPA3) · Studio (hidden, WPA2) · Campus (work or school)
# Passwords carry a colon and spaces on purpose: they must survive the trip from the Core to nmcli.
#   Takumi Home  password "lantern:42 moss"
#   Attic: 5G    password "starlight attic"
#   Studio       hidden: type its name; password "hidden-studio-9"
#   Campus       WPA2-Enterprise from hostapd's own EAP server, PEAP (or TTLS) with MSCHAPv2:
#                username "student@campus.takumi.test", password "library card: 7",
#                server domain campus.takumi.test (Enter takes it from the username).
#                Its server's certificate comes from an authority this script makes and adds to the VM's
#                trusted certificates, standing in for the public ones a real campus uses.
#   wifi-rig.sh            set it up (again)
#   wifi-rig.sh portal     every network now seems to want a sign-in page, like a hotel's
#   wifi-rig.sh no-portal  back to plain internet
set -euo pipefail
conf=/etc/NetworkManager/conf.d/99-takumi-portal-test.conf
case "${1:-}" in
  portal)
    # NetworkManager's check finds a different answer than it expects, which is what a sign-in page does.
    printf '[connectivity]\nuri=http://ping.archlinux.org/nm-check.txt\nresponse=Takumi sign-in test\ninterval=15\n' | sudo tee "$conf" >/dev/null
    sudo nmcli general reload conf; sleep 1; nmcli networking connectivity check; exit 0 ;;
  no-portal)
    sudo rm -f "$conf"; sudo nmcli general reload conf; sleep 1; nmcli networking connectivity check; exit 0 ;;
  "") ;;
  *) echo "usage: wifi-rig.sh [portal|no-portal]" >&2; exit 2 ;;
esac

sudo pacman -S --noconfirm --needed hostapd dnsmasq iw openssl >/dev/null
d=/run/takumi-wifi-rig ns=takumi-ap
if [[ -d $d ]]; then
  for p in "$d"/*.pid; do [[ -f "$p" ]] && sudo kill "$(cat "$p")" 2>/dev/null; done
  sudo rm -rf "$d"
fi
sudo ip netns del "$ns" 2>/dev/null || true
sudo nft delete table ip takumi_rig 2>/dev/null || true
sudo modprobe -r mac80211_hwsim 2>/dev/null || true
sudo modprobe mac80211_hwsim radios=6
sleep 2
sudo mkdir -p "$d"
in_ns() { sudo ip netns exec "$ns" "$@"; }

# The router: its own namespace, an uplink to the VM, and NAT on both hops.
sudo ip netns add "$ns"
for i in wlan0 wlan1 wlan2 wlan3 wlan4; do sudo iw phy "$(cat "/sys/class/net/$i/phy80211/name")" set netns name "$ns"; done
sudo ip link add takumi-up type veth peer name uplink netns "$ns"
sudo nmcli device set takumi-up managed no 2>/dev/null || true
sudo ip addr add 10.70.0.1/30 dev takumi-up; sudo ip link set takumi-up up
# The VM's firewall (install/steps/25-firewall.sh) forwards nothing it was not told to: the router's traffic may pass.
if command -v ufw >/dev/null; then sudo ufw route allow in on takumi-up >/dev/null; fi   # /etc/ufw/user.rules
in_ns ip link set lo up
in_ns ip addr add 10.70.0.2/30 dev uplink; in_ns ip link set uplink up
in_ns ip route add default via 10.70.0.1
in_ns sysctl -qw net.ipv4.ip_forward=1
sudo sysctl -qw net.ipv4.ip_forward=1
in_ns nft -f - <<'NFT'
table ip nat {
  chain post {
    type nat hook postrouting priority 100;
    oifname "uplink" masquerade
  }
}
NFT
sudo nft -f - <<'NFT'
table ip takumi_rig {
  chain post {
    type nat hook postrouting priority 100;
    ip saddr 10.70.0.0/30 masquerade
  }
}
NFT

# Campus's certificates: an authority of its own, a certificate for radius.campus.takumi.test that it signs, and the
# authority added to the VM's trusted certificates, the list the Core checks a work or school network against.
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 30 -sha256 -subj "/CN=Takumi Campus test authority" \
  -keyout "$d/campus-ca.key" -out "$d/campus-ca.pem" 2>/dev/null   # openssl.cnf's v3_ca makes it an authority
sudo openssl req -newkey rsa:2048 -nodes -sha256 -subj "/CN=radius.campus.takumi.test" \
  -keyout "$d/campus-server.key" -out "$d/campus-server.csr" 2>/dev/null
printf '%s\n' "basicConstraints=CA:FALSE" "keyUsage=critical,digitalSignature,keyEncipherment" "extendedKeyUsage=serverAuth" \
  "subjectAltName=DNS:radius.campus.takumi.test" | sudo tee "$d/campus-server.ext" >/dev/null
sudo openssl x509 -req -in "$d/campus-server.csr" -CA "$d/campus-ca.pem" -CAkey "$d/campus-ca.key" -CAcreateserial \
  -days 30 -sha256 -extfile "$d/campus-server.ext" -out "$d/campus-server.pem" 2>/dev/null
sudo install -Dm644 "$d/campus-ca.pem" /etc/ca-certificates/trust-source/anchors/takumi-campus-test.crt   # /etc/ca-certificates/trust-source/anchors/takumi-campus-test.crt
sudo update-ca-trust   # /etc/ssl/certs/ca-certificates.crt
# Anyone may start the outer sign-in; inside it, only the student, with MSCHAPv2 (PEAP) or MSCHAPv2 (TTLS).
printf '%s\n' '* PEAP,TTLS' '"student@campus.takumi.test" MSCHAPV2,TTLS-MSCHAPV2 "library card: 7" [2]' | sudo tee "$d/campus.eap_user" >/dev/null

ap() {  # interface subnet channel ssid [hostapd lines...]
  local i=$1 n=$2 ch=$3 ssid=$4; shift 4
  in_ns ip addr add "10.71.$n.1/24" dev "$i"; in_ns ip link set "$i" up
  printf '%s\n' "interface=$i" "driver=nl80211" "ssid=$ssid" "utf8_ssid=1" "hw_mode=g" "channel=$ch" "$@" \
    | sudo tee "$d/$i.conf" >/dev/null
  in_ns hostapd -B -P "$d/hostapd-$i.pid" "$d/$i.conf" >/dev/null
  in_ns dnsmasq --interface="$i" --bind-interfaces --except-interface=lo --port=0 \
    --dhcp-range="10.71.$n.10,10.71.$n.50,12h" --dhcp-option=option:dns-server,10.0.2.3 --pid-file="$d/dnsmasq-$i.pid"
}
ap wlan0 1 1  "Takumi Home" wpa=2 wpa_key_mgmt=WPA-PSK rsn_pairwise=CCMP "wpa_passphrase=lantern:42 moss"
ap wlan1 2 6  "Corner Café"
ap wlan2 3 11 "Attic: 5G"   wpa=2 wpa_key_mgmt=SAE rsn_pairwise=CCMP ieee80211w=2 "sae_password=starlight attic"
ap wlan3 4 1  "Studio"      wpa=2 wpa_key_mgmt=WPA-PSK rsn_pairwise=CCMP "wpa_passphrase=hidden-studio-9" ignore_broadcast_ssid=1
ap wlan4 5 6  "Campus"      wpa=2 wpa_key_mgmt=WPA-EAP rsn_pairwise=CCMP ieee8021x=1 eap_server=1 "eap_user_file=$d/campus.eap_user" \
  "ca_cert=$d/campus-ca.pem" "server_cert=$d/campus-server.pem" "private_key=$d/campus-server.key"
sleep 1
nmcli device wifi rescan 2>/dev/null || true
echo "wifi rig: Takumi Home (WPA2), Corner Café (open), Attic: 5G (WPA3), Studio (hidden), Campus (work or school) on wlan5, with internet"
