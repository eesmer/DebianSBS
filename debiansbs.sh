#!/bin/bash
#buildnumber:131020

if ! [ -x "$(command -v whiptail)" ]; then
	apt-get -y install whiptail
fi
if ! [ -x "$(command -v wget)" ]; then
	apt-get -y install wget
fi
if ! [ -x "$(command -v ifconfig)" ]; then
	apt-get -y install net-tools
fi
if ! [ -x "$(command -v ack)" ]; then
	apt-get -y install ack-grep
fi

function dns_status(){
DNS_II="Not Installed" && DNS_SS="None"
dpkg -l |grep bind9utils > /dev/null && DNS_II="Installed"
DNS_SS=$(systemctl status bind9.service |grep Active: |cut -d":" -f2 |cut -d" " -f2)
}

function dns_type(){
DNS_TYPE=caching
ack 'forwarders' /etc/bind/named.conf.options > /dev/null && DNS_TYPE=forwarding
}

function dhcp_status(){
DHCP_II="Not Installed"
dpkg -l |grep isc-dhcp-server > /dev/null && DHCP_II="Installed"
DHCP_SS=$(systemctl status isc-dhcp-server.service |grep Active: |cut -d":" -f2 |cut -d" " -f2)
if [ $DHCP_SS = "" ]; then
DHCP_SS="None"
fi
}

function fs_status(){
FS_II="Not Installed"
dpkg -l |grep samba-common-bin > /dev/null && FS_II="Installed"
FS_SS=$(systemctl status smbd.service |grep Active: |cut -d":" -f2 |cut -d" " -f2)
if [ $FS_SS = "" ]; then
FS_SS ="None"
fi
}

dns_status
dns_type
dhcp_status
fs_status

WORK_DIR=/usr/local/debiansbs
mkdir -p $WORK_DIR

function pause(){
local message="$@"
[ -z $message ] && message="Press Enter to continue"
read -p "$message" readEnterKey
}

function show_menu(){
echo ""
echo "   |---------------------------------------------------------------------------------|"
echo "   | DebianSBS             :::.. Small Business Server ..:::                       v1|"
echo "   |---------------------------------------------------------------------------------|"
echo "   | :: DNS Management ::  | :: DHCP Management ::     | :: FileServer Management :: |"
echo "   |---------------------------------------------------------------------------------|"
echo "   | 1.Add a Zone File     | 11.Add a New Scope        | FP:Create Share             |"
echo "   | 2.Remove Zone File    | 12.Remove Scope           | FP:Delete Share             |"
echo "   | 3.Zone List           | 13.Scope List             | FP:Share List               |"
echo "   | 4.Change Type         | 14.Add Fixed Address      | FP:Create User              |"
echo "   | 5.Add Forwarder       | 15.Remove Fixed Address   | FP:Delete User              |"
echo "   | 6.View DNS config     | 16 Fixed Address List     | FP:User List                |"
echo "   |                                                   | FP:Disk Management          |"
echo "   |---------------------------------------------------------------------------------|"
echo "   |                       :::.. Maintenance & Reports ..:::                         |"
echo "   |---------------------------------------------------------------------------------|"
echo "   | 9.Start/Stop Service  | 19.Start/Stop Service     | 29.Start/Stop Service       |"
echo "   | 10.Dns Service Status | 20.Dhcp Service Status    | 30.File Srv. Service Status |"
echo "   |---------------------------------------------------------------------------------|"
echo "   | 50.Add/Remove Service                                                           |"
echo "   |---------------------------------------------------------------------------------|"
echo "   | 99.Exit | 0.About | *FP is future plan                                          |"
echo "   |---------------------------------------------------------------------------------|"
echo "   |                       :::.. DASHBOARD ..:::                                     |"
echo "   -----------------------------------------------------------------------------------"
echo "     DNS Service Status:        $DNS_II    $DNS_SS"
echo "     DHCP Service Status:       $DHCP_II    $DHCP_SS"
echo "     FILESRV Service Status:    $FS_II    $FS_SS"
echo "   -----------------------------------------------------------------------------------"
echo "     Last Event: $LAST_EVENT                                                          "
echo "   -----------------------------------------------------------------------------------"
}

function add_remove_role(){
choice=$(whiptail --title "Add or Remove Role" --radiolist "Choose:" 15 40 6 \
"Add DNS Role" "" "Add DNS Role" \
"Add DHCP Role" "" "Add DHCP Role" \
"Remove DNS Role" "" "Remove Role" \
"Remove DHCP Role" "" "Remove DHCP Role" 3>&1 1>&2 2>&3)
#"Add FileServer Role" "" "Add FileServer Role" \
#"Remove FileServer Role" "" "Remove FileServer Role" 3>&1 1>&2 2>&3)
case $choice in
"Add DNS Role")
dns_install
;;
"Remove DNS Role")
dns_uninstall
;;
"Add DHCP Role")
dhcp_install
;;
"Remove DHCP Role")
dhcp_uninstall
;;
"Add FileServer Role")
fileserver_install
;;
"Remove FileServer Role")
fileserver_uninstall
;;
*)
;;
esac
pause
}

#-------------------------------------------------------------------------------------------------------------------------------
# functions of DNS
#-------------------------------------------------------------------------------------------------------------------------------

function dns_install(){
echo "::Install DNS Service::"
echo "-----------------------"

wget -q --spider https://google.com
if ! [ $? -eq 0 ];
then
whiptail --title "Internet Conn. Control" --msgbox "No internet access! Installation can't continue :(" 10 60  3>&1 1>&2 2>&3
exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get -y install bind9 bind9utils bind9-doc dnsutils
echo "nameserver 127.0.0.1" > /etc/resolv.conf

choice=$(whiptail --title "Select the DNS Server type" --radiolist "Choose:" 15 40 6 \
"Caching DNS Server" "" "Caching DNS Server" \
"Forwarding DNS Server" "" "Forwarding DNS Server" 3>&1 1>&2 2>&3)
case $choice in
"Caching DNS Server")
dns_caching_conf
;;
"Forwarding DNS Server")
dns_forwarding_conf
;;
*)
;;
esac
}

function dns_caching_conf(){
rm /etc/default/bind9
cat > /etc/default/bind9 << EOF
RESOLVCONF=no
OPTIONS="-u bind -4"
EOF
chmod 644 /etc/default/bind9

rm /etc/bind/named.conf.options
cat > /etc/bind/named.conf.options << EOF
acl trust {
localhost;
localnets;
};

options {
directory "/var/cache/bind";
recursion yes;
allow-query { trust; };

dnssec-validation auto;
auth-nxdomain no;
listen-on-v6 { any; };
};
EOF
chmod 644 /etc/bind/named.conf.options
dns_status
systemctl reload bind9.service
LAST_EVENT="DNS service set in caching type"
}

function dns_forwarding_conf(){
rm /etc/default/bind9
cat > /etc/default/bind9 << EOF
RESOLVCONF=no
OPTIONS="-u bind -4"
EOF
chmod 644 /etc/default/bind9

rm /etc/bind/named.conf.options
cat > /etc/bind/named.conf.options << EOF
acl trust {
localhost;
localnets;
};

options {
directory "/var/cache/bind";
recursion yes;
allow-query { trust; };

forwarders {
8.8.8.8;
8.8.4.4;
};
forward only;

dnssec-validation auto;
auth-nxdomain no;
listen-on-v6 { any; };
};
EOF
chmod 644 /etc/bind/named.conf.options
dns_status
LAST_EVENT="DNS service set in forwarding type"
systemctl reload bind9.service
}

function dns_uninstall(){
echo "::DNS uninstall::"
echo "------------------"
apt-get -y purge bind9 bind9utils bind9-doc dnsutils
apt-get -y autoremove
rm -rf /etc/bind
dns_status
LAST_EVENT="DNS Service uninstalled."
}

function add_zone_file(){
if [ "$DNS_II" = Installed ] && [ "$DNS_SS" = active ]
then
	ZONE_NAME=$(whiptail --title "Zone Name" --inputbox "Please enter the Zone Name (example.org)" 10 60  3>&1 1>&2 2>&3)
	A_RECORD=$(whiptail --title "Zone Name" --inputbox "Please enter the IP Address for A Record" 10 60  3>&1 1>&2 2>&3)
	NS_RECORD=$(whiptail --title "Zone Name" --inputbox "Please enter the IP Address for NS Record" 10 60  3>&1 1>&2 2>&3)

	mkdir -p /etc/bind/zones

cat > /etc/bind/zones/db.$ZONE_NAME << EOF

; BIND data file for $ZONE_NAME
@	IN	SOA	ns1.$ZONE_NAME.	admin.$ZONE_NAME. (
00000000        ; Serial
3h              ; Refresh after 3 hours
1h              ; Retry after 1 hour
1w              ; Expire after 1 week
1h )            ; Negative caching TTL of 1 day
;
@               IN      NS	$ZONE_NAME.

$ZONE_NAME.	IN	A	$A_RECORD
ns1		IN	A	$NS_RECORD
EOF

cat >> /etc/bind/named.conf.local << EOF
zone "$ZONE_NAME" { //$ZONE_NAME
type master; //$ZONE_NAME
file "/etc/bind/zones/db.$ZONE_NAME"; //$ZONE_NAME
}; //$ZONE_NAME
EOF
	systemctl reload bind9
	LAST_EVENT="Added new zone file named $ZONE_NAME"
else
	whiptail --title "DNS Service not ready :(" --msgbox "Please check DNS service" 10 60  3>&1 1>&2 2>&3
fi
}

function remove_zone_file(){
ZONE_NAME=$(whiptail --title "Zone Name" --inputbox "Please enter the Zone Name" 10 60  3>&1 1>&2 2>&3)
if [ -f /etc/bind/zones/db.$ZONE_NAME ]
then
	rm /etc/bind/zones/db.$ZONE_NAME
	sed -i /$ZONE_NAME/d /etc/bind/named.conf.local
	sed -i '/^$/d' /etc/bind/named.conf.local
	systemctl reload bind9
	LAST_EVENT="$ZONE_NAME zone deleted."

else
	whiptail --title "Remove zone file" --msgbox "Zone file not found in zones" 10 60  3>&1 1>&2 2>&3
fi

}

function zone_list(){
if [ "$DNS_II" = Installed ]
then
	ls /etc/bind/zones > /tmp/zone-list
	sed -i 's/^...//' /tmp/zone-list
	let i=0
	W=()
	while read -r line; do
		let i=$i+1
		W+=($i "$line")
	done < <( cat /tmp/zone-list)
	IND=$(whiptail --title "DNS Zone List" --menu "Chose one" 24 50 17 "${W[@]}" 3>&2 2>&1 1>&3)
	CHOOSE_ZONE=$(sed -n $IND\p /tmp/zone-list)
	whiptail --scrolltext --title "Content of $CHOOSE_ZONE" --msgbox "$(cat /etc/bind/zones/db.$CHOOSE_ZONE)" 25 80 3>&1 1>&2 2>&3
	LAST_EVENT="Zone named $CHOOSE_ZONE is displayed"
else
	whiptail --title "DNS Service not installed :(" --msgbox "DNS Service not ready. Please check DNS install status" 10 60  3>&1 1>&2 2>&3
fi
}

function change_dns_type(){
if [ "$DNS_II" = Installed ] && [ "$DNS_SS" = active ]
then
	dns_type
	choice=$(whiptail --title "DNS type is "$DNS_TYPE." You can choose a new type" --radiolist "Choose:" 15 70 5 \
		"Caching DNS Server" "" "Caching DNS Server" \
		"Forwarding DNS Server" "" "Forwarding DNS Server" 3>&1 1>&2 2>&3)
			case $choice in
				"Caching DNS Server")
					dns_caching_conf
					;;
				"Forwarding DNS Server")
					dns_forwarding_conf
					;;
				*)
					;;
			esac
else
	whiptail --title "DNS Service not ready :(" --msgbox "Please check DNS service" 10 60  3>&1 1>&2 2>&3
fi
}

function add_forwarder(){
if [ "$DNS_II" = Installed ]
then
FORWARDER1=$(whiptail --title "Add Forwarder" --inputbox "Please enter the First Forwarder IP Adress" 10 60  3>&1 1>&2 2>&3)
FORWARDER2=$(whiptail --title "Add Forwarder" --inputbox "Please enter the Second Forwarder IP Adress" 10 60  3>&1 1>&2 2>&3)

rm /etc/bind/named.conf.options
cat > /etc/bind/named.conf.options << EOF
acl trust {
localhost;
localnets;
};

options {
directory "/var/cache/bind";
recursion yes;
allow-query { trust; };

forwarders {
$FORWARDER1;
$FORWARDER2;
};
forward only;

dnssec-validation auto;
auth-nxdomain no;
listen-on-v6 { any; };
};
EOF
chmod 644 /etc/bind/named.conf.options
systemctl restart bind9.service
systemctl status bind9.service > /tmp/dns_status.txt
dns_status
LAST_EVENT="Add $FORWARDER1 and $FORWARDER2 forwarder in DNS service"

if [ $DNS_TYPE = caching ]
then
	whiptail --title "DNS type changed" --msgbox "DNS type forwarding is done because you are adding forwarder" 10 70  3>&1 1>&2 2>&3
	LAST_EVENT="Add $FORWARDER1 and $FORWARDER2 forwarder in DNS service and DNS type changed to forwarding"
	dns_type
fi
else
	whiptail --title "DNS Service not installed :(" --msgbox "DNS service not ready. Please check DNS Service install status" 10 70  3>&1 1>&2 2>&3
fi

}

function view_dns_config(){
if [ "$DNS_II" = Installed ]
then
	whiptail --scrolltext --title "DNS Status" --msgbox "$(cat /etc/bind/named.conf.options)" 30 120 3>&1 1>&2 2>&3
	LAST_EVENT="DNS service configuration file viewed"
else
	whiptail --title "DNS Service not installed :(" --msgbox "DNS service not ready. Please check DNS Service install status" 10 70  3>&1 1>&2 2>&3
fi
}

function dns_start_stop(){
choice=$(whiptail --title "Start/Stop DNS Service" --radiolist "Choose:" 10 40 5 \
"start" "" start \
"stop" "" stop 3>&1 1>&2 2>&3)
case $choice in
start)
dns_start
;;
stop)
dns_stop
;;
*)
;;
esac
pause
}

function dns_start(){
systemctl start bind9.service
dns_status
systemctl status bind9.service > /tmp/dns_status.txt
whiptail --scrolltext --title "DNS Status" --msgbox "$(cat /tmp/dns_status.txt)" 30 120 3>&1 1>&2 2>&3
LAST_EVENT="DNS service started"
}

function dns_stop(){
systemctl stop bind9.service
dns_status
systemctl status bind9.service > /tmp/dns_status.txt
whiptail --scrolltext --title "DNS Status" --msgbox "$(cat /tmp/dns_status.txt)" 30 120 3>&1 1>&2 2>&3
LAST_EVENT="DNS service stopped"
}

function dns_instant_status(){
systemctl status bind9.service > /tmp/dns_status.txt
whiptail --scrolltext --title "DNS Status" --msgbox "$(cat /tmp/dns_status.txt)" 30 120 3>&1 1>&2 2>&3
LAST_EVENT="Instant status of DNS service was checked"
pause
}

#-------------------------------------------------------------------------------------------------------------------------------
# functions of DHCP
#-------------------------------------------------------------------------------------------------------------------------------

function dhcp_start_stop(){
choice=$(whiptail --title "Start/Stop DHCP Service" --radiolist "Choose:" 10 40 5 \
"start" "" start \
"stop" "" stop 3>&1 1>&2 2>&3)
case $choice in
start)
dhcp_start
;;
stop)
dhcp_stop
;;
*)
;;
esac
pause
}

function dhcp_install(){
echo "::DHCP Install::"
echo "----------------"

# internet connection control
wget -q --spider https://google.com
if ! [ $? -eq 0 ];
then
whiptail --title "Internet Conn. Control" --msgbox "No internet access! Installation can't continue :(" 10 60  3>&1 1>&2 2>&3
exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get -y install isc-dhcp-server
apt-get -y autoclean

ip link |grep pfifo_fast |cut -d':' -f2 |cut -d' ' -f2 > /tmp/interface-list
let i=0
W=()
while read -r line; do
let i=$i+1
W+=($i "$line")
done < <( cat /tmp/interface-list)
IND=$(whiptail --title "Network Adapter Interface List" --menu "Chose one" 24 50 17 "${W[@]}" 3>&2 2>&1 1>&3)
CHOOSE_INTERFACE=$(sed -n $IND\p /tmp/interface-list)
echo INTERFACE="$CHOOSE_INTERFACE" > $WORK_DIR/default

rm -f /etc/default/isc-dhcp-server
cat > /etc/default/isc-dhcp-server << EOF
INTERFACESv4="$CHOOSE_INTERFACE"
EOF
chmod 644 /etc/default/isc-dhcp-server

SCOPE_NAME=$(whiptail --title "Scope Name" --inputbox "Please enter the Scope Name" 10 60  3>&1 1>&2 2>&3)
RANGE_START=$(whiptail --title "Range Start" --inputbox "Please enter the start of range" 10 60  3>&1 1>&2 2>&3)
RANGE_FINISH=$(whiptail --title "Range Finish" --inputbox "Please enter the finish of range" 10 60  3>&1 1>&2 2>&3)
DOMAIN_SEARCH=$(whiptail --title "Domain Search Defination" --inputbox "Please enter the Domain Search defination" 10 60  3>&1 1>&2 2>&3)
DOMAIN_NS=$(whiptail --title "Domain NS Defination" --inputbox "Please enter the Domain NS defination" 10 60  3>&1 1>&2 2>&3)
DEFAULT_LEASE_TIME=$(whiptail --title "Default Lease Time" --inputbox "Please enter the Default Lease Time" 10 60  3>&1 1>&2 2>&3)
MAX_LEASE_TIME=$(whiptail --title "Maximum Lease Time" --inputbox "Please enter the Maximum Lease Time" 10 60  3>&1 1>&2 2>&3)

SUBNET_ADDRESS=$(ip r |grep $CHOOSE_INTERFACE |grep "link src" |cut -d'/' -f1)
SUBNET_MASK=$(ifconfig $CHOOSE_INTERFACE |grep netmask |cut -d'k' -f2 |cut -d' ' -f2)
DEFAULT_ROUTE=$(ip r |grep default |cut -d' ' -f3)

rm -f /etc/dhcp/dhcpd.conf
cat > /etc/dhcp/dhcpd.conf << EOF
ddns-update-style none;
authoritative;
log-facility local7;

# $SCOPE_NAME
subnet $SUBNET_ADDRESS netmask $SUBNET_MASK { #$SCOPE_NAME
range $RANGE_START $RANGE_FINISH; #$SCOPE_NAME
option subnet-mask $SUBNET_MASK; #$SCOPE_NAME
option domain-search "$DOMAIN_SEARCH"; #$SCOPE_NAME
option domain-name-servers $DOMAIN_NS; #$SCOPE_NAME
option routers $DEFAULT_ROUTE; #$SCOPE_NAME
default-lease-time $DEFAULT_LEASE_TIME; #$SCOPE_NAME
max-lease-time $MAX_LEASE_TIME; #$SCOPE_NAME
} #$SCOPE_NAME
EOF

cat > $WORK_DIR/scope_list << EOF
#---------------------------------------------#
# SCOPE LIST                                  #
#---------------------------------------------#
$SCOPE_NAME | $RANGE_START - $RANGE_FINISH
EOF
systemctl restart isc-dhcp-server.service
dhcp_status
LAST_EVENT="DHCP Service installed."
}

function dhcp_uninstall(){
echo "::DHCP uninstall::"
echo "------------------"
apt-get -y purge isc-dhcp-server
apt-get -y autoremove
dhcp_status
LAST_EVENT="DHCP Service uninstalled."
}

function dhcp_add_new_scope(){
echo "::Add a New Scope::"
echo "-------------------"
source $WORK_DIR/default
SCOPE_NAME=$(whiptail --title "Scope Name" --inputbox "Please enter the Scope Name" 10 60  3>&1 1>&2 2>&3)
RANGE_START=$(whiptail --title "Range Start" --inputbox "Please enter the start of range" 10 60  3>&1 1>&2 2>&3)
RANGE_FINISH=$(whiptail --title "Range Finish" --inputbox "Please enter the finish of range" 10 60  3>&1 1>&2 2>&3)
DOMAIN_SEARCH=$(whiptail --title "Domain Search Defination" --inputbox "Please enter the Domain Search defination" 10 60  3>&1 1>&2 2>&3)
DOMAIN_NS=$(whiptail --title "Domain NS Defination" --inputbox "Please enter the Nameserver defination" 10 60  3>&1 1>&2 2>&3)
DEFAULT_LEASE_TIME=$(whiptail --title "Default Lease Time" --inputbox "Please enter the Default Lease Time" 10 60  3>&1 1>&2 2>&3)
MAX_LEASE_TIME=$(whiptail --title "Maximum Lease Time" --inputbox "Please enter the Maximum Lease Time" 10 60  3>&1 1>&2 2>&3)

SUBNET_ADDRESS=$(ip r |grep $INTERFACE |grep "link src" |cut -d'/' -f1)
SUBNET_MASK=$(ifconfig $INTERFACE |grep netmask |cut -d'k' -f2 |cut -d' ' -f2)

cat >> /etc/dhcp/dhcpd.conf << EOF

# $SCOPE_NAME
subnet $SUBNET_ADDRESS netmask $SUBNET_MASK { #$SCOPE_NAME
range $RANGE_START $RANGE_FINISH; #$SCOPE_NAME
option subnet-mask $SUBNET_MASK; #$SCOPE_NAME
option domain-search "$DOMAIN_SEARCH"; #$SCOPE_NAME
option domain-name-servers $DOMAIN_NS; #$SCOPE_NAME
default-lease-time $DEFAULT_LEASE_TIME; #$SCOPE_NAME
max-lease-time $MAX_LEASE_TIME; #$SCOPE_NAME
} #$SCOPE_NAME
EOF

cat >> $WORK_DIR/scope_list << EOF
$SCOPE_NAME | $RANGE_START - $RANGE_FINISH
EOF

systemctl restart isc-dhcp-server.service
dhcp_status
LAST_EVENT="$SCOPE_NAME scope has been added on DHCP service"
pause
}

function dhcp_add_fixed_address(){
echo "::Add a New Fixed Address::"
echo "---------------------------"
HOST_NAME=$(whiptail --title "Hostname" --inputbox "Please enter the Hostname" 10 60  3>&1 1>&2 2>&3)
MAC_ADDRESS=$(whiptail --title "MAC/Hardware Address" --inputbox "Please enter the MAC Address of client ethernet adapter" 10 60  3>&1 1>&2 2>&3)
IP_ADDRESS=$(whiptail --title "IP Address" --inputbox "Please enter the IP Address to be assigned" 10 60  3>&1 1>&2 2>&3)

cat >> /etc/dhcp/dhcpd.conf << EOF
# $HOST_NAME Fixed Address
host $HOST_NAME { #$HOST_NAME
hardware ethernet $MAC_ADDRESS; #$HOST_NAME
fixed-address $IP_ADDRESS; #$HOST_NAME
} #$HOST_NAME
EOF

if [ -f "$WORK_DIR/fixed_address_list" ];
then
cat >> $WORK_DIR/fixed_address_list << EOF
$HOST_NAME | $IP_ADDRESS
EOF
else
cat > $WORK_DIR/fixed_address_list << EOF
#---------------------------------------------#
# FIXED ADDRESS LIST                          #
#---------------------------------------------#
$HOST_NAME | $IP_ADDRESS
EOF
fi
systemctl restart isc-dhcp-server.service
dhcp_status
LAST_EVENT="$IP_ADDRESS IP Address is fixedly assigned to $HOST_NAME device"
pause
}

function dhcp_remove_scope(){
echo "::Remove Scope::"
echo "----------------"

SCOPE_NAME=$(whiptail --title "Scope Name" --inputbox "Please enter the Scope Name" 10 60  3>&1 1>&2 2>&3)
STATUS=FALSE
ack $SCOPE_NAME /etc/dhcp/dhcpd.conf > /dev/null && STATUS=TRUE

SCOPE_NUM=$(cat /usr/local/debiansrv/scope_list | wc -l)
if [ $SCOPE_NUM = 4 ];
then
STATUS=LASTSCOPE
fi

if [ "$STATUS" = TRUE ]
then
sed -i /$SCOPE_NAME/d /etc/dhcp/dhcpd.conf
sed -i /$SCOPE_NAME/d $WORK_DIR/scope_list
sed -i '/^$/d' /etc/dhcp/dhcpd.conf
sed -i '/^$/d' $WORK_DIR/scope_list
systemctl restart isc-dhcp-server.service
elif [ "$STATUS" = LASTSCOPE ]
then
whiptail --title "Scope delete error" --msgbox "Last scope cannot be deleted. There must be at least one scope." 10 60  3>&1 1>&2 2>&3
else
whiptail --title "Scope delete error" --msgbox "Scope Name Not Found!" 10 60  3>&1 1>&2 2>&3
fi
dhcp_status
LAST_EVENT="$SCOPE_NAME scope removed from DHCP service"
pause
}

function dhcp_remove_fixed_address(){
echo "::Remove Fixed Address::"
echo "------------------------"
HOST_NAME=$(whiptail --title "Host Name" --inputbox "Please enter the Host Name" 10 60  3>&1 1>&2 2>&3)
STATUS=FALSE
ack $HOST_NAME /etc/dhcp/dhcpd.conf > /dev/null && STATUS=TRUE

if [ "$STATUS" = TRUE ]
then
sed -i /$HOST_NAME/d /etc/dhcp/dhcpd.conf
sed -i /$HOST_NAME/d $WORK_DIR/fixed_address_list
sed -i '/^$/d' $WORK_DIR/fixed_address_list
sed -i '/^$/d' /etc/dhcp/dhcpd.conf
systemctl restart isc-dhcp-server.service
else
whiptail --title "Remove Scope Error" --msgbox "Host Name Not Found!" 10 60  3>&1 1>&2 2>&3
fi
dhcp_status
LAST_EVENT="Fixed IP definition for device $HOST_NAME removed"
pause
}

function dhcp_scope_list(){
whiptail --scrolltext --title "Current Scope List" --msgbox "$(cat $WORK_DIR/scope_list)" 25 65 3>&1 1>&2 2>&3
LAST_EVENT="The list of defined scopes in the DHCP service has been received"
pause
}

function dhcp_fixed_address_list(){
whiptail --scrolltext --title "Current Fixed Address List" --msgbox "$(cat $WORK_DIR/fixed_address_list)" 25 65 3>&1 1>&2 2>&3
LAST_EVENT="The list of defined IP addresses in the DHCP service has been received"
pause
}

function dhcp_start(){
systemctl start isc-dhcp-server.service
dhcp_status
systemctl status isc-dhcp-server.service > /tmp/dhcp_status.txt
whiptail --scrolltext --title "DHCP Status" --msgbox "$(cat /tmp/dhcp_status.txt)" 30 120 3>&1 1>&2 2>&3
LAST_EVENT="DHCP service started"
}

function dhcp_stop(){
systemctl stop isc-dhcp-server.service
dhcp_status
systemctl status isc-dhcp-server.service > /tmp/dhcp_status.txt
whiptail --scrolltext --title "DHCP Status" --msgbox "$(cat /tmp/dhcp_status.txt)" 30 120 3>&1 1>&2 2>&3
LAST_EVENT="DHCP service stopped"
}

function dhcp_instant_status(){
systemctl status isc-dhcp-server.service > /tmp/dhcp_status.txt
whiptail --scrolltext --title "DHCP Status" --msgbox "$(cat /tmp/dhcp_status.txt)" 30 120 3>&1 1>&2 2>&3
LAST_EVENT="Instant status of DHCP service was checked"
pause
}
#-------------------------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------------------------
# function of FileServer
#-------------------------------------------------------------------------------------------------------------------------------
function fileserver_install(){
echo "::Install FileServer Service::"
echo "------------------------------"

wget -q --spider https://google.com
if ! [ $? -eq 0 ];
then
	whiptail --title "Internet Conn. Control" --msgbox "No internet access! Installation can't continue :(" 10 60  3>&1 1>&2 2>&3
fi

export DEBIAN_FRONTEND=noninteractive
apt-get -y install samba --install-recommends
fs_status
LAST_EVENT="FileServer role installed."
}


#-------------------------------------------------------------------------------------------------------------------------------
function about_of(){
echo ""
echo "::..About of DebianSBS..::"
cat about
pause
}

function read_input(){
local c
read -p "You can choose from the menu numbers " c
case $c in
#0)about_of ;;
1)add_zone_file;;
2)remove_zone_file;;
3)zone_list;;
4)change_dns_type;;
5)add_forwarder;;
6)view_dns_config;;
9)dns_start_stop ;;
10)dns_instant_status;;
#-----------------------------
11)dhcp_add_new_scope;;
12)dhcp_remove_scope;;
13)dhcp_scope_list;;
14)dhcp_add_fixed_address;;
15)dhcp_remove_fixed_address;;
16)dhcp_fixed_address_list;;
19)dhcp_start_stop;;
20)dhcp_instant_status;;
#-----------------------------
50)add_remove_role;;
99)exit 0 ;;
*)
echo "Please select from the menu numbers"
pause
esac
}

# CTRL+C, CTRL+Z
trap '' SIGINT SIGQUIT SIGTSTP

while true
do
clear
show_menu
read_input
done
