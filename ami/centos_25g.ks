#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
url --url="http://repos.internal.mxplay.com/7/base"
ignoredisk --only-use=xvda
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
repo --name=updates --baseurl="http://repos.internal.mxplay.com/7/updates"
network --device eth0 --bootproto dhcp
rootpw --iscrypted nope
services --enabled="chronyd"
timezone Asia/Kolkata --isUtc
bootloader --location=mbr --boot-drive=xvda --append="console=tty0 console=ttyS0,115200"
clearpart --all --drives=xvda --initlabel
part /boot --fstype="ext2" --ondisk=xvda --size=500
part pv.12 --fstype="lvmpv" --ondisk=xvda --size=24200
volgroup centos --pesize=4096 pv.12
logvol /  --fstype="xfs" --size=24000 --name=root --vgname=centos
firewall --disabled
selinux --disabled

%packages
@core
chrony
curl
acpid
-NetworkManager
-aic94xx-firmware
-alsa-firmware
-alsa-lib
-alsa-tools-firmware
-biosdevname
-iprutils
-ivtv-firmware
-iwl100-firmware
-iwl1000-firmware
-iwl105-firmware
-iwl135-firmware
-iwl2000-firmware
-iwl2030-firmware
-iwl3160-firmware
-iwl3945-firmware
-iwl4965-firmware
-iwl5000-firmware
-iwl5150-firmware
-iwl6000-firmware
-iwl6000g2a-firmware
-iwl6000g2b-firmware
-iwl6050-firmware
-iwl7260-firmware
-libertas-sd8686-firmware
-libertas-sd8787-firmware
-libertas-usb8388-firmware
-plymouth
%end

%post
rm /etc/hostname

versions=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel)
for i in $versions; do
  dracut -f /boot/initramfs-$i.img $i
done

sed -i -e 's/ rhgb quiet//' /boot/grub/grub.conf
sed -i -e 's/GRUB_CMDLINE_LINUX="console=tty0 /GRUB_CMDLINE_LINUX="net.ifnames=0 console=tty0 /' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

passwd -d root
passwd -l root
curl http://repos.internal.mxplay.com/yum/rc.local > /etc/rc.local
chmod +x /etc/rc.local

cat > /etc/sysconfig/network << EOF
NETWORKING=yes
NOZEROCONF=yes
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
PEERDNS="yes"
IPV6INIT="no"
PERSISTENT_DHCLIENT=1
EOF

rm /etc/sysconfig/network-scripts/ifcfg-ens3

#setup yum
sed -i 's/enabled=1/enabled=0/g' /etc/yum/pluginconf.d/fastestmirror.conf
curl http://repos.internal.mxplay.com/yum/base.repo > /etc/yum.repos.d/CentOS-Base.repo
curl http://repos.internal.mxplay.com/yum/epel.repo > /etc/yum.repos.d/epel.repo
#curl http://repos.internal.mxplay.com/yum/elrepo.repo > /etc/yum.repos.d/elrepo.repo
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
yum -y --disablerepo=epel install epel-release
#rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
yum -y update
yum -y install dnsmasq sysstat
yum -y install vim bash-completion tmux

systemctl enable dnsmasq
systemctl enable sysstat

# remove unnecessary packages
yum -y remove linux-firmware firewalld NetworkManager kexec-tools wpa_supplicant iwl7265-firmware postfix tuned

# dhclient
cat > /etc/dhcp/dhclient.conf << EOF
timeout 180;
retry 60;
prepend domain-name-servers 127.0.0.1;
EOF

yum clean all
truncate -c -s 0 /var/log/yum.log

#clear machine-id
> /etc/machine-id

#ssh
sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
rm -f /etc/ssh/ssh_host_*

#make rc-local run only after network is up
mkdir -p /etc/systemd/system/rc-local.service.d

cat > /etc/systemd/system/rc-local.service.d/override.conf << EOF
[Unit]
Wants=network-online.target
After=network-online.target
EOF

package-cleanup --oldkernels
/sbin/halt
%end
