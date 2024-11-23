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
