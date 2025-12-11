#!/bin/bash

purple() { echo -e "\033[35m$1\033[0m"; }

echo ""
purple "=== SERV00 | CT8 By:Djkyc 一键保活（最终加强版 + 自动识别平台 + 合并TG消息）===\n"

# 账号脱敏函数
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

# 自动识别平台（大写）
detect_platform() {
    local host="$1"

    if [[ "$host" == *"serv00.com"* ]]; then
        echo "SERV00"
    elif [[ "$host" == *.ct8.* ]]; then
        echo "CT8"
    else
        echo "UNKNOWN"
    fi
}

# Telegram 推送函数
send_tg() {
    local message="$1"
    [[ -z "$TG_TOKEN" || -z "$CHAT_ID" ]] && return

    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "parse_mode=Markdown" \
        --data-urlencode "text=$message" >/dev/null
}

# 参数
accounts_file="$1"
TG_TOKEN="$2"
CHAT_ID="$3"

accounts=$(jq -c '.[]' "$accounts_file")

success_list=""
fail_list=""
summary_details=""
success_count=0
fail_count=0

# SSH 登录（带重试）
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

# 遍历账户
for account in $accounts; do
    ip=$(echo "$account" | jq -r '.ip')
    username=$(echo "$account" | jq -r '.username')
    password=$(echo "$account" | jq -r '.password')
    port=$(echo "$account" | jq -r '.port // 22')

    masked_user=$(mask_username "$username")
    platform=$(detect_platform "$ip")

    echo "激活中：***$platform*** $masked_user@$ip"

    if try_login "$ip" "$username" "$password" "$port"; then
        success_list+="🟢 [**$platform**] $masked_user@$ip"$'\n'
        summary_details+="🟢 **$platform 激活成功**：\`$masked_user@$ip\`"$'\n'
        ((success_count++))
    else
        sleep 2
        if try_login "$ip" "$username" "$password" "$port"; then
            success_list+="🟢 [**$platform**] $masked_user@$ip"$'\n'
            summary_details+="🟢 **$platform 激活成功（重试成功）**：\`$masked_user@$ip\`"$'\n'
            ((success_count++))
        else
            fail_list+="🔴 [**$platform**] $masked_user@$ip"$'\n'
            summary_details+="🔴 **$platform 激活失败**：\`$masked_user@$ip\`"$'\n'
            ((fail_count++))
        fi
    fi
done

# === 修复后的 final_msg（无错误） ===
final_msg=$'📊 **SERV00 / CT8 激活结果汇总**\n'
final_msg+=$'------------------------------\n\n'

final_msg+="$summary_details"$'\n'

final_msg+="*成功：* $success_count"$'\n'
final_msg+="*失败：* $fail_count"$'\n\n'

final_msg+=$'*成功列表：*\n'"${success_list:-无}"$'\n'
final_msg+=$'*失败列表：*\n'"${fail_list:-无}"$'\n'

# 推送到 Telegram
send_tg "$final_msg"

echo -e "$final_msg"
