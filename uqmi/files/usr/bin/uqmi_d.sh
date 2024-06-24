#!/bin/sh
#
# uqmi daemon, runs every 30sec
# 1. Check IP-address in get-current-settings
#
# by mrhaav 2024-06-24

. /lib/functions.sh
. /lib/netifd/netifd-proto.sh

interface=$(uci show network | grep qmi | awk -F . '{print $2}')
device=$(uci get network.${interface}.device)
default_profile=$(uci get network.${interface}.default_profile)
ipv6profile=$(uci get network.${interface}.ipv6profile)
smsc=$(uci get network.${interface}.smsc)

json_load "$(ubus call network.interface.${interface} status)"
json_get_var ifname l3_device
json_select data
json_get_vars cid_4 pdh_4 cid_6 pdh_6 zone

if [ ! -n "$pdh_4" ] && [ ! -n "$pdh_6" ]
then
	/etc/init.d/uqmi_d stop 2> /dev/null
fi

logger -t uqmi_d Daemon started


while true
do
	
# Check wwan connectivity
	if [ -n "$pdh_4" ]
	then
		ipv4connected="$(uqmi -s -d $device --set-client-id wds,$cid_4 --get-current-settings)"
	fi
	if [ -n "$pdh_6" ]
	then
		ipv6connected="$(uqmi -s -d $device --set-client-id wds,$cid_6 --get-current-settings)"
	fi

	if [ "$ipv4connected" = '"Out of call"' ] || [ "$ipv6connected" = '"Out of call"' ]
	then
		logger -t uqmi_d Modem disconnected
		proto_init_update "$ifname" 0
		proto_send_update "$interface"

# IPv4
		if [ -n "$pdh_4" ]
		then
			uqmi -s -d $device --set-client-id wds,"$cid_4" \
				--release-client-id wds

			cid_4=$(uqmi -s -d $device --get-client-id wds)
			uqmi -s -d "$device" --set-client-id wds,"$cid_4" --set-ip-family ipv4
			pdh_4=$(uqmi -s -d $device --set-client-id wds,"$cid_4" \
				--start-network \
				--profile $default_profile)
			if [ "$pdh_4" = '"Call failed"' ]
			then
				logger -t uqmi_d 'Unable to re-connect IPv4 - Interface restarted'
				ifup $interface
				/etc/init.d/uqmi_d stop
			else
				logger -t uqmi_d IPv4 re-connected
			fi
			proto_init_update "$ifname" 1
			proto_set_keep 1
			proto_add_data
			json_add_string "cid_4" "$cid_4"
			json_add_string "pdh_4" "$pdh_4"
			json_add_string zone "$zone"
			proto_close_data
			proto_send_update "$interface"
	
			json_load "$(uqmi -s -d $device --set-client-id wds,$cid_4 --get-current-settings)"
			json_select ipv4
			json_get_var ip_4 ip
			json_get_var gateway_4 gateway
			json_get_var dns1_4 dns1
			json_get_var dns2_4 dns2
			json_get_var subnet_4 subnet
	
			proto_init_update "$ifname" 1
			proto_set_keep 1
			proto_add_ipv4_address "$ip_4" "$subnet_4"
			proto_add_ipv4_route "$gateway_4" "128"
			[ "$defaultroute" = 0 ] || proto_add_ipv4_route "0.0.0.0" 0 "$gateway_4"
			[ "$peerdns" = 0 ] || {
				proto_add_dns_server "$dns1_4"
				proto_add_dns_server "$dns2_4"
			}
			proto_send_update "$interface"
		fi

# IPv6
		if [ -n "$pdh_6" ]
		then
			uqmi -s -d $device --set-client-id wds,"$cid_6" \
				--release-client-id wds

			cid_6=$(uqmi -s -d $device --get-client-id wds)
			uqmi -s -d "$device" --set-client-id wds,"$cid_6" --set-ip-family ipv6
			if [ -n "$pdh_4" ] && [ -n "$pdh_6" ]
			then
				pdh_6=$(uqmi -s -d $device --set-client-id wds,"$cid_6" \
					--start-network)
			elif [ -n "$ipv6profile" ]
			then
				pdh_6=$(uqmi -s -d $device --set-client-id wds,"$cid_6" \
					--start-network \
					--profile $ipv6profile)
			else
				pdh_6=$(uqmi -s -d $device --set-client-id wds,"$cid_6" \
					--start-network \
					--profile $default_profile)
			fi
			if [ "$pdh_6" = '"Call failed"' ]
			then
				logger -t uqmi_d 'Unable to re-connect IPv6 - Interface restarted'
				ifup $interface
				/etc/init.d/uqmi_d stop
			else
				logger -t uqmi_d IPv6 re-connected
			fi
			proto_init_update "$ifname" 1
			proto_set_keep 1
			proto_add_data
			json_add_string "cid_6" "$cid_6"
			json_add_string "pdh_6" "$pdh_6"
			json_add_string zone "$zone"
			proto_close_data
			proto_send_update "$interface"

			json_load "$(uqmi -s -d $device --set-client-id wds,$cid_6 --get-current-settings)"
			json_select ipv6
			json_get_var ip_6 ip
			json_get_var gateway_6 gateway
			json_get_var dns1_6 dns1
			json_get_var dns2_6 dns2
			json_get_var ip_prefix_length ip-prefix-length

			proto_init_update "$ifname" 1
			proto_set_keep 1
			proto_add_ipv6_address "$ip_6" "128"
			proto_add_ipv6_prefix "${ip_6}/${ip_prefix_length}"
			proto_add_ipv6_route "$gateway_6" "128"
			[ "$defaultroute" = 0 ] || proto_add_ipv6_route "::0" 0 "$gateway_6" "" "" "${ip_6}/${ip_prefix_length}"
			[ "$peerdns" = 0 ] || {
				proto_add_dns_server "$dns1_6"
				proto_add_dns_server "$dns2_6"
			}
			proto_send_update "$interface"
		fi
		
		json_load "$(ubus call network.interface.${interface} status)"
		json_select data
		json_get_vars cid_4 pdh_4 cid_6 pdh_6
	fi

	sleep 30
done
