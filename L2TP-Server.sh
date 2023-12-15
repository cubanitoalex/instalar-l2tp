#!/bin/bash


NETWORK_INTERFACE=$(ip route | awk '/default/ { print $5 }')


sudo systemctl stop strongswan xl2tpd
sudo apt remove --purge -y strongswan xl2tpd netfilter-persistent
sudo rm -rf /etc/ipsec.conf /etc/ipsec.secrets /etc/xl2tpd /etc/sysctl.conf /etc/ppp


[ -e /etc/ppp/options.xl2tpd ] && sudo rm /etc/ppp/options.xl2tpd
[ -e /etc/ppp/chap-secrets ] && sudo rm /etc/ppp/chap-secrets


sudo mkdir -p /etc/ppp


export DEBIAN_FRONTEND=noninteractive
sudo apt update
sudo apt install -y strongswan xl2tpd netfilter-persistent


echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p


cat <<EOF | sudo tee /etc/ipsec.conf > /dev/null
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, 0"
    uniqueids=yes
    strictcrlpolicy=no

conn L2TP-PSK
    authby=secret
    auto=add
    keyingtries=3
    dpddelay=30
    dpdtimeout=120
    dpdaction=clear
    rekey=yes
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%any
    leftprotoport=udp/1701
    right=%any
    rightprotoport=udp/0
    forceencaps=yes
EOF


IPSEC_SECRET_KEY=$(openssl rand -hex 16)
echo "$IPSEC_SECRET_KEY" | sudo tee /etc/ipsec.secrets > /dev/null


sudo mkdir -p /etc/xl2tpd
cat <<EOF | sudo tee /etc/xl2tpd/xl2tpd.conf > /dev/null
[global]
ipsec saref = yes

[lns default]
ip range = 192.168.42.10-192.168.42.50
local ip = 192.168.42.1
refuse chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF


sudo touch /etc/ppp/options.xl2tpd
cat <<EOF | sudo tee /etc/ppp/options.xl2tpd > /dev/null
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
asyncmap 0
auth
crtscts
lock
hide-password
modem
debug
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
defaultroute
EOF




sudo iptables -t nat -A POSTROUTING -o $NETWORK_INTERFACE -j MASQUERADE
sudo iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
sudo netfilter-persistent save



echo " "
echo " "
echo "         L2TP-server!"
echo " "
echo "==================================================="
echo "|| IP: $(hostname -I)                            ||"
echo "|| IPsec Key: $IPSEC_SECRET_KEY  ||"
echo "==================================================="

sudo touch /etc/ppp/chap-secrets
USERS=("mine1" "mine2" "mine3")
for USER in "${USERS[@]}"; do
    PASSWORD=$(openssl rand -base64 12)
    echo "$USER l2tpd $PASSWORD *" | sudo tee -a /etc/ppp/chap-secrets > /dev/null
    echo "|| Usuario: $USUARIO Contraseña: $CONTRASEÑA  ||"
    
done
echo "==================================================="
echo " "
echo " "

sudo systemctl restart strongswan-starter xl2tpd