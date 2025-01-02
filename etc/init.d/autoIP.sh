步骤

# 变量初始化
enabled=uci get
run_mode=uci get 
bindType=uci get 
interface="lan"
# 是否启用
# 获取运行模式
# 旁路由模式
if [ "$run_mode" == "bypass" ]; then
    # 只检查lan口，不检查WAN口ip
fi
# 正常模式,没有绑定，直接使用wan口  
if [ "$run_mode" == "general" ]; then
    # 检查WAN口ip，考虑lan口ip与wan口ip是否冲突
    wan_ip=$(ubus call network.interface.wan status | grep "ipv4-address" -A 6 | grep -v "ipv6"  | grep "\"address" | cut -d '"' -f 4)
    lan_ip=$(ubus call network.interface.lan status | grep "ipv4-address" -A 6 | grep -v "ipv6"  | grep "\"address" | cut -d '"' -f 4)
    wan_network=$(echo $wan_ip | cut -d '.' -f 1-3)
    lan_network=$(echo $lan_ip | cut -d '.' -f 1-3)
    
    # 判断是否在同一网段
    if [ "$wan_network" == "$lan_network" ]; then
        echo "wan IP 和 lan IP 在同一网段"
    else
        echo "wan IP 和 lan IP 不在同一网段"
    fi

fi
# 绑定模式
if [ "$bindType" == "iface" ]; then
    # 获取接口
    interface=$(uci show network | grep eth0 | grep -v wan6 | grep -v lan6 | cut -d "." -f2 | tr -d "'")
    if echo "$interface" | grep -q "@"; then
        name=$(uci get network.$interface.name)
        interface=$(uci show network | grep $name | grep -v wan6 | grep -v lan6 | cut -d "." -f2 | tr -d "'" | grep -v $interface)
    fi

    # 获取IP地址
    up_status=$(ubus call network.interface.interface status | jsonfilter -e '@.up')
    if $up_status; then
        ipv4_address=$(ubus call network.interface.$interface status | grep "ipv4-address" -A 6 | grep -v "ipv6"  | grep "\"address" | cut -d '"' -f 4)
    fi
    
else
    
fi
# 绑定网卡

# 绑定接口

#!/bin/bash

# 获取wan口IP地址信息（假设格式为xxx.xxx.xxx.xxx/xx）
wan_info=$(ubus call network.interface.wan status | grep '"ipv4\[0\]\.address"' | awk -F'"' '{print $4 "/" $8}')
wan_ip=$(echo $wan_info | cut -d '/' -f 1)
wan_mask=$(echo $wan_info | cut -d '/' -f 2)

# 获取lan口IP地址信息（假设格式为xxx.xxx.xxx.xxx/xx）
lan_info=$(ubus call network.interface.lan status | grep '"ipv4\[0\]\.address"' | awk -F'"' '{print $4 "/" $8}')
lan_ip=$(echo $lan_info | cut -d '/' -f 1)
lan_mask=$(echo $lan_info | cut -d '/' -f 2)

# 检查是否成功获取IP和掩码信息
if [ -z "$wan_ip" ] || [ -z "$lan_ip" ] || [ -z "$wan_mask" ] || [ -z "$lan_mask" ]; then
    echo "未能成功获取wan或lan的IP地址及掩码信息"
    exit 1
fi

# 将IP地址和掩码按.分割为数组
IFS='.' read -r -a wan_ip_parts <<< "$wan_ip"
IFS='.' read -r -a wan_mask_parts <<< "$wan_mask"
IFS='.' read -r -a lan_ip_parts <<< "$lan_ip"
IFS='.' read -r -a lan_mask_parts <<< "$lan_mask"

# 计算网络地址（通过按位与操作）
wan_network=""
lan_network=""
for ((i = 0; i < 4; i++)); do
    wan_network_part=$((10#${wan_ip_parts[$i]} & 10#${wan_mask_parts[$i]}))
    lan_network_part=$((10#${lan_ip_parts[$i]} & 10#${lan_mask_parts[$i]}))
    wan_network="$wan_network$wan_network_part"
    lan_network="$lan_network$lan_network_part"
    if [ $i -lt 3 ]; then
        wan_network="$wan_network."
        lan_network="$lan_network."
    fi
done

# 判断是否在同一网段
if [ "$wan_network" = "$lan_network" ]; then
    echo "wan IP和lan IP在同一网段，需要对lan IP进行网段变换"

    # 找到第一个非255的网络位，从第二段（索引为1）开始判断，避免网络位为0或255
    change_index=0
    for ((i = 1; i < 4; i++)); do
        if [ "${lan_ip_parts[$i]}" -lt 255 ]; then
            change_index=$i
            break
        fi
    done

    if [ $change_index -eq 0 ]; then
        echo "无法进行有效的网段变换，lan IP的网络位已达最大值"
        exit 1
    fi

    # 对找到的网络位加1进行网段变换
    ((lan_ip_parts[$change_index]++))
    for ((i = change_index + 1; i < 4; i++)); do
        lan_ip_parts[$i]=0
    done

    # 重新组合新的lan IP地址
    new_lan_ip=$(printf "%d.%d.%d.%d" "${lan_ip_parts[@]}")
    echo "新的lan IP地址为: $new_lan_ip"

    # 这里可添加实际修改lan接口IP地址配置的代码，例如通过uci命令等，以下是简单示例注释
    # uci set network.lan.ipaddr="$new_lan_ip"
    # uci commit network
    # /etc/init.d/network restart
else
    echo "wan IP和lan IP不在同一网段，无需进行网段变换"
fi

-----------------------------
#!/bin/bash
ubus monitor network.interface | while read line; do
    echo "$line" | grep -q '{"interface":"wan","action":"up"}'
    if [ $? -eq 0 ]; then
        logger -t wan-script "WAN interface is up, running your script here"
        # 在此处添加你要执行的脚本命令或调用其他脚本
        /usr/bin/your-script.sh
    fi
done

# 豆包生成，当检测到WAN口与lan口网段一致时，自动修改lan口ip地址
wanaddr=$(ubus call network.interface.wan status | grep "address" | grep -oe '(0-9){1,3}\.(0-9){1,3}\.(0-9){1,3}\.(0-9){1,3}' | grep -oe '(0-9){1,3}\.(0-9){1,3}\.(0-9){1,3}\.')
lanaddr=$(ubus call network.interface.lan status | grep "address" | grep -oe '(0-9){1,3}\.(0-9){1,3}\.(0-9){1,3}\.(0-9){1,3}' | grep -oe '(0-9){1,3}\.(0-9){1,3}\.(0-9){1,3}\.')
echo "$wanaddr $lanaddr" > /dev/console
if [ "x$wanaddr" == "x$lanaddr" ]; then
    if [ "x$wanaddr" == "x192.168.10.1" ]; then
        uci set network.lan.ipaddr='193.168.20.1'
    else
        uci set network.lan.ipaddr='193.168.10.1'
    fi
    uci commit
    /etc/init.d/network restart
fi

# 豆包生成，当检测到WAN口与lan口网段一致时，自动修改lan口ip地址
# 在 /etc/hotplug.d/iface 目录下创建名为 99-auto-change-lan-ip.sh 的脚本
if [ "$action" == "ifup" ] && [ "$interface" == "wan" ]; then
    wan_ip=$(ifconfig $interface | grep "inet addr" | awk '{print $2}' | cut -d ':' -f 2)
    # 假设当WAN口IP地址在192.168.0.0/16网段时修改LAN口IP
    if echo $wan_ip | grep -qE '192.168\.[0-9]{1,3}\.[0-9]{1,3}'; then
        uci set network.lan.ipaddr='10.0.0.1'
        uci commit
        /etc/init.d/network restart
    fi
fi

# 发送消息部分
KEY_MSG=""
WEBHOOK_TOKEN=""
WEBHOOK_URL="https://oapi.dingtalk.com/robot/send?access_token=""$WEBHOOK_TOKEN"
 
function sendMessage(){
    # 钉钉群组自定义机器人的Webhook URL

    MESSAGE="$KEY_MSG\n""$1"
    
    # 使用curl发送POST请求
    curl -H "Content-Type: application/json" -X POST -d "
    {
        \"msgtype\": \"text\",
        \"text\": {
            \"content\": \"$MESSAGE\"
        }
    }" $WEBHOOK_URL
}
