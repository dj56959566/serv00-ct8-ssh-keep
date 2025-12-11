#!/bin/bash

green="\033[32m"
yellow="\033[33m"
red="\033[31m"
purple() { echo -e "\033[35m$1\033[0m"; }
re="\033[0m"

echo ""
purple "=== serv00 | AM科技 一键保活脚本（增强 TG 版）===\n"

# Telegram 发送函数（支持 Markdown）
send_tg() {
    local message="$1"
    [[ -z "$TG_TOKEN" || -z "$CHAT_ID" ]] && return

    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "parse_mode=Markdown" \
        -d "text=$message" >/dev/null
}

# 参数检查
if [[ $# -lt 1 ]]; then
    echo "用法: $0 <accounts.json>"
    exit 1
fi

accounts_file="$1"
TG_TOKEN="$2"
CHAT_ID="$3"

accounts=$(jq -c '.[]' "$accounts_file")
total_accounts=$(echo "$accounts" | wc -l)
success_list=""
fail_list=""

echo "::info::共检测到 $total_accounts 个账户"

# SSH 尝试函数（带1次重试）
try_login() {
    local ip="$1"
    local username="$2"
    local password="$3"

    sshpass -p "$password" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=20 \
        -o ServerAliveInterval=10 \
        -o ServerAliveCountMax=2 \
        -tt "$username@$ip" "echo ok; sleep 1; exit" >/dev/null 2>&1
}

for account in $accounts; do
    ip=$(echo "$account" | jq -r '.ip')
    username=$(echo "$account" | jq -r '.username')
    password=$(echo "$account" | jq -r '.password')

    [[ -z "$ip" || -z "$username" ]] && continue

    echo "正在激活：$username@$ip"

    # 第一次尝试
    if try_login "$ip" "$username" "$password"; then
        success_list+="🟢 $username@$ip\n"
        send_tg "🟢 *serv00 激活成功*\n账号：\`$username@$ip\`"
    else
        echo "第一次失败，准备重试..."

        sleep 3

        # 第二次重试
        if try_login "$ip" "$username" "$password"; then
            success_list+="🟢 $username@$ip\n"
            send_tg "🟢 *serv00 激活成功（重试成功）*\n账号：\`$username@$ip\`"
        else
            fail_list+="🔴 $username@$ip\n"
            send_tg "🔴 *serv00 激活失败*\n账号：\`$username@$ip\`\n重试：失败"
        fi
    fi
done

# 最终总结
summary="📊 *serv00 批量激活完成*\n
*成功：* $(echo -e "$success_list" | wc -l)
*失败：* $(echo -e "$fail_list" | wc -l)\n
———\n"

summary+="*成功列表：*\n${success_list:-无}\n"
summary+="*失败列表：*\n${fail_list:-无}\n"

send_tg "$summary"
echo -e "$summary"
