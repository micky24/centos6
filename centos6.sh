#!/bin/bash

# initialisasi var
OS=`uname -m`;
MYIP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | grep -v '127.0.0.2'`;
MYIP2="s/xxxxxxxxx/$MYIP/g";
# go to root
cd

# disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.d/rc.local

# install wget and curl
yum -y install wget curl

# set time GMT +7
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# set locale
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
service sshd restart

# setting repo
wget http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
rpm -Uvh epel-release-6-8.noarch.rpm
rpm -Uvh remi-release-6.rpm

if [ "$OS" == "x86_64" ]; then
  wget http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm
  rpm -Uvh rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm
else
  wget http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el6.rf.i686.rpm
  rpm -Uvh rpmforge-release-0.5.3-1.el6.rf.i686.rpm
fi

sed -i 's/enabled = 1/enabled = 0/g' /etc/yum.repos.d/rpmforge.repo
sed -i -e "/^\[remi\]/,/^\[.*\]/ s|^\(enabled[ \t]*=[ \t]*0\\)|enabled=1|" /etc/yum.repos.d/remi.repo
rm -f *.rpm

# remove unused
yum -y remove sendmail;
yum -y remove httpd;
yum -y remove cyrus-sasl;
yum -y remove samba

# update
yum -y update

# insert SWAP file
sudo dd if=/dev/zero of=/swapfile bs=1024 count=1024k
sudo mkswap /swapfile
sudo swapon /swapfile
sed -i '$ i\/swapfile          swap            swap    defaults        0 0' /etc/fstab
chown root:root /swapfile 
chmod 0600 /swapfile
sysctl vm.swappiness=10
sed -i '$ i\/vm.swappiness=10' /etc/sysctl.conf
sleep 6

# install webserver
yum -y install nginx php-fpm php-cli
service nginx restart
service php-fpm restart
chkconfig nginx on
chkconfig php-fpm on

# install essential package
yum -y install rrdtool screen iftop htop nmap bc nethogs vnstat ngrep mtr git zsh mrtg unrar rsyslog rkhunter mrtg net-snmp net-snmp-utils expect nano bind-utils
yum -y groupinstall 'Development Tools'
yum -y install cmake

yum -y --enablerepo=rpmforge install axel sslh ptunnel unrar

# disable exim
service exim stop
chkconfig exim off

# setting vnstat
vnstat -u -i venet0
echo "MAILTO=root" > /etc/cron.d/vnstat
echo "*/5 * * * * root /usr/sbin/vnstat.cron" >> /etc/cron.d/vnstat
sed -i 's/eth0/venet0/g' /etc/sysconfig/vnstat
service vnstat restart
chkconfig vnstat on

# install screenfetch
cd
wget https://github.com/KittyKatt/screenFetch/raw/master/screenfetch-dev
mv screenfetch-dev /usr/bin/screenfetch
chmod +x /usr/bin/screenfetch
echo "clear" >> .bash_profile
echo "screenfetch" >> .bash_profile

# install webserver
cd
wget -O /etc/nginx/nginx.conf "https://raw.github.com/micky24/centos6/master/nginx.conf"
sed -i 's/www-data/nginx/g' /etc/nginx/nginx.conf
mkdir -p /home/vps/public_html
echo "<pre>Setup by micky24</pre>" > /home/vps/public_html/index.html
echo "<?php phpinfo(); ?>" > /home/vps/public_html/info.php
rm /etc/nginx/conf.d/*
wget -O /etc/nginx/conf.d/vps.conf "https://raw.github.com/micky24/centos6/master/vps.conf"
sed -i 's/apache/nginx/g' /etc/php-fpm.d/www.conf
chmod -R +rx /home/vps
service php-fpm restart
service nginx restart

# install openvpn
wget -O /etc/openvpn/openvpn.tar "https://raw.github.com/micky24/debian7/master/openvpn-debian.tar"
cd /etc/openvpn/
tar xf openvpn.tar
wget -O /etc/openvpn/1194.conf "https://raw.github.com/micky24/centos6/master/vps.conf"
if [ "$OS" == "x86_64" ]; then
  wget -O /etc/openvpn/1194.conf "https://raw.github.com/micky24/centos6/master/1194-centos64.conf"
fi
wget -O /etc/iptables.up.rules "https://raw.github.com/micky24/centos6/master/iptables.up.rules"
sed -i '$ i\iptables-restore < /etc/iptables.up.rules' /etc/rc.local
sed -i '$ i\iptables-restore < /etc/iptables.up.rules' /etc/rc.d/rc.local
sed -i $MYIP2 /etc/iptables.up.rules;
iptables-restore < /etc/iptables.up.rules
sysctl -w net.ipv4.ip_forward=1
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
service openvpn restart
chkconfig openvpn on
cd

# configure openvpn client config
cd /etc/openvpn/
wget -O /etc/openvpn/1194-client.ovpn "https://raw.github.com/micky24/centos6/master/1194-client.conf"
sed -i $MYIP2 /etc/openvpn/1194-client.ovpn;
PASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 15 | head -n 1`;
useradd -M -s /bin/false micky24
echo "micky24:$PASS" | chpasswd
echo "username" > pass.txt
echo "password" >> pass.txt
tar cf client.tar 1194-client.ovpn pass.txt
cp client.tar /home/vps/public_html/
cd

# install badvpn
wget -O /usr/bin/badvpn-udpgw "https://raw.github.com/micky24/centos6/master/badvpn-udpgw"
if [ "$OS" == "x86_64" ]; then
  wget -O /usr/bin/badvpn-udpgw "https://raw.github.com/micky24/centos6/master/badvpn-udpgw64"
fi
sed -i '$ i\screen -AmdS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300' /etc/rc.local
sed -i '$ i\screen -AmdS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300' /etc/rc.d/rc.local
chmod +x /usr/bin/badvpn-udpgw
screen -AmdS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300

# install mrtg
#wget -O /etc/snmp/snmpd.conf "https://raw.github.com/micky24/centos6/master/snmpd.conf"
#wget -O /root/mrtg-mem.sh "https://raw.github.com/micky24/centos6/master/mrtg-mem.sh"
#chmod +x /root/mrtg-mem.sh
#service snmpd restart
#chkconfig snmpd on
#snmpwalk -v 1 -c public localhost | tail
#mkdir -p /home/vps/public_html/mrtg
#cfgmaker --zero-speed 100000000 --global 'WorkDir: /home/vps/public_html/mrtg' --output /etc/mrtg/mrtg.cfg public@localhost
#curl  "https://raw.github.com/micky24/centos6/master/mrtg.conf" >> /etc/mrtg/mrtg.cfg
#sed -i 's/WorkDir: \/var\/www\/mrtg/# WorkDir: \/var\/www\/mrtg/g' /etc/mrtg/mrtg.cfg
#sed -i 's/# Options\[_\]: growright, bits/Options\[_\]: growright/g' /etc/mrtg/mrtg.cfg
#indexmaker --output=/home/vps/public_html/mrtg/index.html /etc/mrtg/mrtg.cfg
#echo "0-59/5 * * * * root env LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg" > /etc/cron.d/mrtg
#LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg
#LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg
#LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg
#cd

# setting port ssh
sed -i '/Port 22/a Port 143' /etc/ssh/sshd_config
sed -i 's/Port 22/Port  22/g' /etc/ssh/sshd_config
service sshd restart
chkconfig sshd on

# install dropbear
wget http://dl.fedoraproject.org/pub/epel/6/i386/dropbear-2015.67-1.el6.i686.rpm
rpm -Uvh dropbear-2015.67-1.el6.i686.rpm
yum -y install dropbear
echo "OPTIONS=\"-p 443\"" > /etc/sysconfig/dropbear
echo "/bin/false" >> /etc/shells
echo "/sbin/nologin" >> /etc/shells
service dropbear restart
chkconfig dropbear on

# install vnstat gui
#cd /home/vps/public_html/
#wget http://www.sqweek.com/sqweek/files/vnstat_php_frontend-1.5.1.tar.gz
#tar xf vnstat_php_frontend-1.5.1.tar.gz
#rm vnstat_php_frontend-1.5.1.tar.gz
#mv vnstat_php_frontend-1.5.1 vnstat
#cd vnstat
#sed -i 's/eth0/venet0/g' config.php
#sed -i "s/\$iface_list = array('venet0', 'sixxs');/\$iface_list = array('venet0');/g" config.php
#sed -i "s/\$language = 'nl';/\$language = 'en';/g" config.php
#sed -i 's/Internal/Internet/g' config.php
#sed -i '/SixXS IPv6/d' config.php
cd

# install fail2ban
yum -y install fail2ban
service fail2ban restart
chkconfig fail2ban on

# install squid
yum -y install squid
wget -O /etc/squid/squid.conf "https://raw.github.com/micky24/centos6/master/squid-centos.conf"
sed -i $MYIP2 /etc/squid/squid.conf;
service squid restart
chkconfig squid on

# install webmin
cd
wget http://ncu.dl.sourceforge.net/project/webadmin/webmin/1.760/webmin-1.760-1.noarch.rpm
yum -y install perl perl-Net-SSLeay openssl perl-IO-Tty
rpm -U webmin-1.760-1.noarch.rpm
service webmin restart
chkconfig webmin on

# install bmon
if [ "$OS" == "x86_64" ]; then
  wget -O /usr/bin/bmon "https://raw.github.com/micky24/centos6/master/bmon64"
else
  wget -O /usr/bin/bmon "https://raw.github.com/micky24/centos6/master/bmon"
fi
chmod +x /usr/bin/bmon

# download script
cd
wget -O speedtest_cli.py "https://raw.github.com/sivel/speedtest-cli/master/speedtest_cli.py"
wget -O bench-network.sh "https://raw.github.com/micky24/centos6/master/bench-network.sh"
wget -O ps_mem.py "https://raw.github.com/pixelb/ps_mem/master/ps_mem.py"
wget -O userlogin.sh "https://raw.github.com/micky24/centos6/master/userlogin.sh"
wget -O userexpired.sh "https://raw.github.com/micky24/centos6/master/userexpired.sh"
#wget -O sof "https://raw.github.com/micky24/centos6/master/sof"
#chmod +x sof
chmod +x bench-network.sh
chmod +x speedtest_cli.py
chmod +x ps_mem.py
chmod +x userlogin.sh
chmod +x userexpired.sh
echo "*/10 * * * * root /root/userexpired.sh" >> /etc/cron.d/userexpired
#echo "0 */6 * * * root /sbin/reboot" > /etc/cron.d/reboot


# cron
service crond start
chkconfig crond on

# limit user 2 bitvise per port
#iptables -A INPUT -p tcp --syn --dport 80 -m connlimit --connlimit-above 2 -j REJECT
iptables -A INPUT -p tcp --syn --dport 22 -m connlimit --connlimit-above 2 -j REJECT
iptables -A INPUT -p tcp --syn --dport 443 -m connlimit --connlimit-above 2 -j REJECT
iptables -A INPUT -p tcp --syn --dport 1194 -m connlimit --connlimit-above 2 -j REJECT
iptables -A INPUT -p tcp --syn --dport 7300 -m connlimit --connlimit-above 2 -j REJECT
iptables -A INPUT -p udp --syn --dport 7300 -m connlimit --connlimit-above 2 -j REJECT
iptables-save > /etc/iptables.up.rules
chkconfig iptables on

# finishing
chown -R nginx:nginx /home/vps/public_html
service nginx restart
service php-fpm restart
service vnstat restart
service openvpn restart
service snmpd restart
service sshd restart
service dropbear restart
service fail2ban restart
service squid restart
service webmin restart
service crond restart
chkconfig crond on
rm -rf ~/.bash_history && history -c
echo "unset HISTFILE" >> /etc/profile

rm -rf centos*
