#!/bin/bash

green="\033[32m"
yellow="\033[33m"
red="\033[31m"
purple() { echo -e "\033[35m$1\033[0m"; }
re="\033[0m"

echo ""
purple "=== serv00 | ct8 一键保活（最终版 + 自动识别平台 + TG脱敏）===\n"

# 账号脱敏函数（自动打码）
mask_username() {
    local name="$1"
    local len=${#name}

    if (( len <= 3 )); then
        echo "***"
    elif (( len <= 5 )); then
        echo "${name:0:2}***"
    else
        echo "${name:0:3}***${name:len-2:2}"
    fi
}

# 自动识别平台函数
detect_platform() {
    local host="$1"

    if [[ "$host" == *"serv00.com"* ]]; then
        echo "serv00"
    elif [[ "$host" == *.ct8.* ]]; then
        echo "CT8"
    else
        echo "未知平台"
    fi
}

# Telegram 推送（支持换行 + Markdown）
send_tg() {
    local message="$1"
    [[ -z "$TG_TOKEN" || -z "$CHAT_ID" ]] && return
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "parse_mode=Markdown" \
        --data-urlencode "text=$message" >/dev/null
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

echo "::info::共检测到 $total_accounts 个账户"
echo "----------------------------"

success_list=""
fail_list=""
success_count=0
fail_count=0

# SSH 登录函数（带重试）
try_login() {
    local ip="$1"
    local username="$2"
    local password="$3"
    local port="${4:-22}"

    sshpass -p "$password" ssh \
        -p "$port" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=20 \
        -o ServerAliveInterval=10 \
        -o ServerAliveCountMax=2 \
        -tt "$username@$ip" "echo ok; sleep 1; exit" >/dev/null 2>&1
}

# 遍历所有账户
for account in $accounts; do
    ip=$(echo "$account" | jq -r '.ip')
    username=$(echo "$account" | jq -r '.username')
    password=$(echo "$account" | jq -r '.password')
    port=$(echo "$account" | jq -r '.port // 22')

    masked_user=$(mask_username "$username")
    platform=$(detect_platform "$ip")  # ← 自动识别 serv00 / CT8 / 未知平台

    echo "正在激活：[$platform] $masked_user@$ip ..."

    # 第一次尝试
    if try_login "$ip" "$username" "$password" "$port"; then
        success_list+="🟢 [$platform] $masked_user@$ip"$'\n'
        ((success_count++))

        send_tg $'🟢 *'"$platform"$' 激活成功*\n账号：`'"$masked_user@$ip"'`'
    else
        echo "第一次失败，准备重试..."
        sleep 2

        # 第二次重试
        if try_login "$ip" "$username" "$password" "$port"; then
            success_list+="🟢 [$platform] $masked_user@$ip"$'\n'
            ((success_count++))

            send_tg $'🟢 *'"$platform"$' 激活成功（重试成功）*\n账号：`'"$masked_user@$ip"'`'
        else
            fail_list+="🔴 [$platform] $masked_user@$ip"$'\n'
            ((fail_count++))

            send_tg $'🔴 *'"$platform"$' 激活失败*\n账号：`'"$masked_user@$ip"'`'
        fi
    fi

    echo "----------------------------"
done

# 最终总结消息
summary=$'📊 *serv00 / CT8 批量激活结果*\n'
summary+=$'-------------------------\n'
summary+=$'*成功：* '"$success_count"$'\n'
summary+=$'*失败：* '"$fail_count"$'\n\n'

summary+=$'*成功列表：*\n'
summary+="${success_list:-无}"$'\n'

summary+=$'*失败列表：*\n'
summary+="${fail_list:-无}"$'\n'

send_tg "$summary"

echo -e "$summary"
