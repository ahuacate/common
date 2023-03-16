<h2>Local DNS Records</h2>

Some network DNS servers may not map arbitrary hostnames to their static IP addresses. UniFi for example.

UniFi UGS/UDM routers only resolves locally assigned DHCP client hostnames. This means hard-static set IP addresses or pfSense issued DHCP clients hostnames will not be mapped by any UniFi DHCP client.

Use Linux command `nslookup hostname` on your PVE host to check if hard-static IP client hostnames are being mapped. If you are using UniFi as your router you will find there are issues.

The partial fix is to install a PVE CT PiHole DNS server to resolve arbitrary hostnames to their IP addresses. Our PiHole CT installer is available [here](https://github.com/aquacate/pve-homelab). Navigate using the PiHole web interface to `Settings` > `DNS tab` and complete as follows (change to match your network).

:white_check_mark: Use DNSSEC
:white_check_mark: Use Conditional Forwarding

|Local network in CIDR|IP address of your DHCP server (router)|Local domain name
|----|----|----
|192.168.0.0/24|192.168.1.5|local

At the time of writing, PiHole WebGUI only allows for one conditional forward entry. From an SSH session to your Pi-hole DNS server create a PiHole host custom file using command/path `nano /etc/dnsmasq.d/01-custom.conf`. In this file we add the following server entries (amend to your chosen IPv4 addresses):

```
server=/local/192.168.30.5 # LAN-vpngate-world
server=/local/192.168.40.5 # LAN-vpngate-local
server=/168.192.in-addr.arpa/192.168.1.5 # UniFi UGS/UDM router
server=/168.192.in-addr.arpa/192.168.30.5 # LAN-vpngate-world
server=/168.192.in-addr.arpa/192.168.40.5 # LAN-vpngate-local

strict-order
```

Then navigate using the PiHole web interface to `Local DNS` > `DNS record` adding any client which uses hard-static IP addresses like the following records (change to match your network).

|Domain|IP address
|----|----
|nas-01.local|192.168.1.10
|nas-02.local|192.168.1.11
|pve-01.local|192.168.1.101
|pve-02.local|192.168.1.102
|pve-03.local|192.168.1.103
|pve-04.local|192.168.1.104
|pve-05.local|192.168.1.105

And restart your PiHole device.

Finally edit all your Proxmox hosts DNS setting (in identical order, PiHole DNS first) as follows.

|Type|Value|Description
|----|----|----
|Search Domain|local
|DNS Server 1|192.168.1.6|This is your PiHole server IP address
|DNS Server 2|192.168.1.5|This is your network router DNS IP


> Note: The network Local Domain or Search domain must be set. We recommend only top-level domain (spTLD) names for residential and small networks names because they cannot be resolved across the internet. Routers and DNS servers know, in theory, not to forward ARPA requests they do not understand onto the public internet. It is best to choose one of our listed names: local, home.arpa, localdomain or lan only. Do NOT use made-up names.
