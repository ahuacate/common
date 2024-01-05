<h2>About the Ahuacate environment</h2>

All Ahuacate builds are constructed upon a shared Linux user, group, and file storage environment that caters to all our Proxmox Virtual Machines (VMs) and Linux Containers (LXCs).

To ensure the proper functioning of any of our VMs and LXCs, <span style="color:red">it is essential</span> to set up your NAS storage and Proxmox hosts.

<hr>

<h5>Device naming conventions</h5>

We implement a straightforward device naming system for all devices, seamlessly compatible with our scripts. We strongly advise following this convention to prevent installation issues and ensure smooth operation.

* `pve-01, pve-02, pve-03`: Proxmox hostname naming convention.
* `nas-01, nas-02, nas-03`: NAS hostname naming convention.

Our default local domain name is `local`.

<h5>System wide Users and Groups</h5>

* `media:medialab - 1605:65605`: Encompasses all aspects related to media, such as movies, TV, and music.
* `home:homelab - 1606:65606`: Pertains to smart home functionalities, such as cctv, HA, Syncthing, including medialab privileges.
* `private:privatelab - 1607:65607`: Reserved for power, trusted, administration users, private storage with medialab and homelab permissions.
* `chrootjail - 65608`: Pertains to restricted, standard and jailed user accounts.

Usernames media, home, and private are employed to execute Proxmox LXC software applications. For instance, the user media and group medialab are utilized for Sonarr, Radarr, and all media-related Proxmox LXCs. Similarly, the user home and group homelab are employed for HomeAssistant.

<h5>Network-Attached Storage (NAS) for File Storage</h5>

Proxmox necessitates the presence of a NAS. Your NAS should feature a collection of folder shares within a 'storage volume.' These newly created folder shares are subsequently mounted by your Proxmox Virtual Environment (PVE) hosts as either NFS or SMB/CIFS mount points, contributing to the establishment of your PVE host backend storage (e.g., pve-01).

In our terminology, the NAS 'storage volume' is denoted as your NAS 'base folder.'

> As an illustration, on a Synology NAS, the default volume is /volume1. Therefore, on a Synology device, our "base folder" would be: /volume1.

It's possible that your NAS already incorporates some of the requisite folder structures. If this is the case, please ensure the creation of the sub-directory where applicable. Additionally, your NAS should include the necessary users and groups, and it must support ACL permissions.

Due to the presence of numerous base and sub-folders featuring intricate ACL permissions, we highly recommend utilizing our Easy Scripts for the seamless construction of a fully-supported NAS storage device. Our NAS Easy Scripts are compatible with Synology, OMV, and a Proxmox Virtual Environment (PVE) hosted Ubuntu NAS system.

To gain a deeper understanding of the necessary NAS folder shares, subfolders and permissions, you can refer to our code list by clicking the links provided below:

<a href="https://github.com/ahuacate/common/tree/main/nas/src/nas_basefolderlist" target="_blank">See list of base folders</a>
<a href="https://github.com/ahuacate/common/tree/main/nas/src/nas_basefolderlist" target="_blank">See list of subfolders</a>

You can find comprehensive installation instructions, set up Easy Scripts, and review system requirements in this location.

<a href="https://github.com/ahuacate/nas-hardmetal" target="_blank">Hardmetal NAS guide</a>
<a href="https://github.com/ahuacate/pve-nas" target="_blank">Proxmox NAS VM guide</a>

<h5>Proxmox Hosts</h5>

Once you have prepared your NAS shares, the next step is to configure your Proxmox hosts by setting up bind-mounted shared data, storage, and other necessary configurations.

You can find comprehensive installation instructions, set up Easy Scripts, and review system requirements in this location.

<a href="https://github.com/ahuacate/pve-host" target="_blank">Proxmox host guide</a>

<hr>