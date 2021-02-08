#!/usr/bin/env bash

# Unprivileged container mapping
msg "MediaLab unprivileged PVE CT mapping..."
echo -e "lxc.idmap: u 0 100000 1605
lxc.idmap: g 0 100000 100
lxc.idmap: u 1605 1605 1
lxc.idmap: g 100 100 1
lxc.idmap: u 1606 101606 63930
lxc.idmap: g 101 100101 65435
lxc.idmap: u 65604 65604 100
lxc.idmap: g 65604 65604 100" >> /etc/pve/lxc/$CTID.conf
grep -qxF 'root:65604:100' /etc/subuid || echo 'root:65604:100' >> /etc/subuid
grep -qxF 'root:65604:100' /etc/subgid || echo 'root:65604:100' >> /etc/subgid
grep -qxF 'root:100:1' /etc/subgid || echo 'root:100:1' >> /etc/subgid
grep -qxF 'root:1605:1' /etc/subuid || echo 'root:1605:1' >> /etc/subuid
info "Unprivileged CT '$CTID' UID mapping is set: ${YELLOW}media${NC}"
info "Unprivileged CT '$CTID' GID mapping is set: ${YELLOW}medialab${NC}."
echo
