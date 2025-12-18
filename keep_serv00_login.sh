#!/bin/bash

purple() { echo -e "\033[35m$1\033[0m"; }

echo ""
purple "=== SERV00 | CT8 By:Djkyc 一键保活（最终版｜自动识别平台｜TG 简洁模板）===\n"

# ========= 账号脱敏 =========
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

# ========= 平台识别 =========
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

# ========= 时间 =========
get_utc_time() {
    date -u "+%Y-%m-%d %H:%M:%S"
}

get_bj_time() {
    TZ=Asia/Shanghai date "+%Y-%m-%d %H:%M:%S"
}

# ========= Telegram 推送 =========
send_tg() {
    local message="$1"
    [[ -z "$TG_TOKEN" || -z "$CHAT_ID" ]] && return

    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "parse_mode=Markdown" \
        --data-urlencode "text=$message" >/dev/null
}

# ========= 参数 =========
accounts_file="$1"
TG_TOKEN="$2"
CHAT_ID="$3"

accounts=$(jq -c '.[]' "$accounts_file")

success_lines=""
fail_lines=""
success_count=0
fail_count=0

# ========= SSH 登录（带一次重试） =========
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

# ========= 遍历账号 =========
for account in $accounts; do
    ip=$(echo "$account" | jq -r '.ip')
    username=$(echo "$account" | jq -r '.username')
    password=$(echo "$account" | jq -r '.password')
    port=$(echo "$account" | jq -r '.port // 22')

    masked_user=$(mask_username "$username")
    platform=$(detect_platform "$ip")

    echo "激活中：$platform $masked_user@$ip"

    if try_login "$ip" "$username" "$password" "$port"; then
        success_lines+="🟢 $platform 激活成功：$masked_user@$ip"$'\n'
        ((success_count++))
    else
        sleep 2
        if try_login "$ip" "$username" "$password" "$port"; then
            success_lines+="🟢 $platform 激活成功：$masked_user@$ip"$'\n'
            ((success_count++))
        else
            fail_lines+="🔴 $platform 激活失败：$masked_user@$ip"$'\n'
            ((fail_count++))
        fi
    fi
done

# ========= 生成 TG 消息 =========
utc_time=$(get_utc_time)
bj_time=$(get_bj_time)

final_msg=$'📊 **SERV00 / CT8 激活结果汇总**\n'
final_msg+=$'🕒 **更新时间：**\n'
final_msg+="• UTC： $utc_time"$'\n'
final_msg+="• 北京时间： $bj_time"$'\n\n'

# 成功播报
if [[ -n "$success_lines" ]]; then
    final_msg+="$success_lines"$'\n'
fi

# 失败列表
final_msg+=$'❌ **失败列表：**\n'
final_msg+="${fail_lines:-无}"

# ========= 推送 =========
send_tg "$final_msg"

echo -e "$final_msg"
