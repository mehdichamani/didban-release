#!/usr/bin/env bash
# ==============================================================================
# 🛡️ سامانه پایش دوربین و تجهیزات دیدبان (Didban)
# اسکریپت نصب و به‌روزرسانی تعاملی خودکار برای لینوکس (Linux Installer & Updater)
# ==============================================================================
set -euo pipefail

REPO_RELEASE="mehdichamani/didban-release"
LATEST_URL="https://github.com/${REPO_RELEASE}/releases/latest/download/didban-linux-x86_64.tar.gz"

# رنگ‌ها برای خروجی زیبا
CLR_RESET="\033[0m"
CLR_RED="\033[1;31m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_BLUE="\033[1;34m"
CLR_CYAN="\033[1;36m"
CLR_BOLD="\033[1m"
CLR_DIM="\033[2m"

print_header() {
    echo -e "${CLR_CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║        🛡️ سامانه پایش و مانیتورینگ دوربین دیدبان (Didban)     ║"
    echo "  ║           اسکریپت نصب و به‌روزرسانی سریع و هوشمند            ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${CLR_RESET}"
}

log_info() {
    echo -e " ${CLR_BLUE}●${CLR_RESET} ${CLR_BOLD}[اطلاع]${CLR_RESET} $1"
}

log_ok() {
    echo -e " ${CLR_GREEN}✔${CLR_RESET} ${CLR_BOLD}[موفق]${CLR_RESET} $1"
}

log_warn() {
    echo -e " ${CLR_YELLOW}▲${CLR_RESET} ${CLR_BOLD}[هشدار]${CLR_RESET} $1"
}

log_err() {
    echo -e " ${CLR_RED}✖${CLR_RESET} ${CLR_BOLD}[خطا]${CLR_RESET} $1" >&2
}

# خواندن تعاملی ورودی حتی در صورتی که اسکریپت با pipe اجرا شده باشد (curl ... | bash)
prompt_input() {
    local prompt_msg="$1"
    local default_val="$2"
    local result=""

    if [ -n "$default_val" ]; then
        echo -ne " ${CLR_CYAN}؟${CLR_RESET} ${prompt_msg} [${CLR_YELLOW}${default_val}${CLR_RESET}]: " > /dev/tty
    else
        echo -ne " ${CLR_CYAN}؟${CLR_RESET} ${prompt_msg}: " > /dev/tty
    fi

    read -r result < /dev/tty
    if [ -z "$result" ]; then
        echo "$default_val"
    else
        echo "$result"
    fi
}

prompt_secret() {
    local prompt_msg="$1"
    local result=""
    echo -ne " ${CLR_CYAN}🔒${CLR_RESET} ${prompt_msg}: " > /dev/tty
    read -r -s result < /dev/tty
    echo "" > /dev/tty
    echo "$result"
}

check_dependencies() {
    local missing=()
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        missing+=("curl یا wget")
    fi
    if ! command -v tar &>/dev/null; then
        missing+=("tar")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_err "پیش‌نیازهای زیر یافت نشدند: ${missing[*]}"
        log_info "لطفاً ابتدا آنها را با مدیر بسته سیستم خود (apt/dnf/pacman) نصب کنید."
        exit 1
    fi
}

suggest_install_ffmpeg() {
    echo ""
    echo -e "${CLR_BOLD}قابلیت جانبی: پخش زنده تصاویر (Live RTSP Stream via FFmpeg)${CLR_RESET}"
    if command -v ffmpeg &>/dev/null; then
        log_ok "ابزار FFmpeg روی سیستم شناسایی شد (قابلیت پخش زنده فعال است)."
        return 0
    fi

    log_warn "ابزار FFmpeg شناسایی نشد."
    log_info "سامانه دیدبان بدون FFmpeg به طور کامل کار می‌کند (پایش وضعیت، دیتابیس، پنل وب و اسنپ‌شات‌ها فعالند)."
    log_info "ابزار FFmpeg صرفاً جهت پخش زنده جریان دوربین‌ها در مرورگر (Live Stream) کاربرد دارد."

    local want_ffmpeg
    want_ffmpeg="$(prompt_input "آیا مایل به نصب خودکار ابزار FFmpeg هستید؟ (y/n)" "n")"
    if [[ ! "$want_ffmpeg" =~ ^[Yy]$ ]]; then
        log_info "از نصب FFmpeg صرف‌نظر شد. در صورت نیاز می‌توانید آن را در آینده نصب کنید."
        return 0
    fi

    log_info "تلاش برای نصب سریع FFmpeg با مدیر بسته‌های سیستم..."
    local installed=false

    if command -v apt-get &>/dev/null; then
        log_info "سیستم‌عامل بر پایه دبیان/اوبونتو شناسایی شد (apt-get)..."
        if [ "$(id -u)" -eq 0 ]; then
            apt-get update -y && apt-get install -y ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo apt-get update -y && sudo apt-get install -y ffmpeg && installed=true || true
        fi
    elif command -v pacman &>/dev/null; then
        log_info "سیستم‌عامل آرچ لینوکس شناسایی شد (pacman)..."
        if [ "$(id -u)" -eq 0 ]; then
            pacman -Sy --noconfirm ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo pacman -Sy --noconfirm ffmpeg && installed=true || true
        fi
    elif command -v dnf &>/dev/null; then
        log_info "سیستم‌عامل RHEL/Fedora/Rocky شناسایی شد (dnf)..."
        if [ "$(id -u)" -eq 0 ]; then
            dnf install -y ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo dnf install -y ffmpeg && installed=true || true
        fi
    elif command -v yum &>/dev/null; then
        log_info "سیستم‌عامل CentOS/RHEL شناسایی شد (yum)..."
        if [ "$(id -u)" -eq 0 ]; then
            yum install -y ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo yum install -y ffmpeg && installed=true || true
        fi
    elif command -v zypper &>/dev/null; then
        log_info "سیستم‌عامل openSUSE شناسایی شد (zypper)..."
        if [ "$(id -u)" -eq 0 ]; then
            zypper --non-interactive install ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo zypper --non-interactive install ffmpeg && installed=true || true
        fi
    fi

    if [ "$installed" = true ] && command -v ffmpeg &>/dev/null; then
        log_ok "ابزار FFmpeg با موفقیت روی سرور نصب و فعال شد."
    else
        log_warn "نصب خودکار FFmpeg به دلیل عدم دسترسی روت یا تفاوت مخازن انجام نشد."
        log_info "در صورت تمایل، می‌توانید آن را به صورت دستی نصب کرده یا باینری مستقل را از سایت رسمی دانلود نمایید:"
        log_info "🔗 صفحه رسمی دانلود FFmpeg: https://ffmpeg.org/download.html"
    fi
}

download_file() {
    local url="$1"
    local dest="$2"

    if command -v curl &>/dev/null; then
        curl -fsSL --progress-bar -o "$dest" "$url"
    else
        wget -q --show-progress -O "$dest" "$url"
    fi
}

# مسیر پیش‌فرض نصب
get_default_install_dir() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "/opt/didban"
    else
        echo "${HOME}/didban"
    fi
}

update_didban() {
    local target_dir="$1"
    log_info "در حال آماده‌سازی برای به‌روزرسانی سامانه در: ${CLR_BOLD}${target_dir}${CLR_RESET}"

    # ۱. متوقف کردن سرویس در صورت فعال بودن
    local systemd_was_active=false
    if command -v systemctl &>/dev/null && systemctl is-active --quiet didban 2>/dev/null; then
        log_info "متوقف‌سازی سرویس didban جهت اعمال به‌روزرسانی..."
        if [ "$(id -u)" -eq 0 ]; then
            systemctl stop didban
        else
            sudo systemctl stop didban
        fi
        systemd_was_active=true
    fi

    # متوقف‌سازی پروسه‌های مستقل احتمالی
    pkill -f "${target_dir}/main.bin" 2>/dev/null || true

    # ۲. دانلود آخرین نسخه
    local tmp_archive
    tmp_archive="$(mktemp /tmp/didban_update_XXXXXX.tar.gz)"
    log_info "در حال دریافت آخرین نسخه از مخزن رسمی دیدبان..."
    if ! download_file "$LATEST_URL" "$tmp_archive"; then
        log_err "دانلود بسته با شکست مواجه شد. لطفاً اتصال اینترنت خود را بررسی کنید."
        rm -f "$tmp_archive"
        exit 1
    fi

    # ۳. استخراج و جایگزینی باینری بدون تغییر در داده‌ها و تنظیمات
    log_info "در حال استخراج و جایگزینی فایل‌های جدید..."
    local tmp_extract
    tmp_extract="$(mktemp -d /tmp/didban_ext_XXXXXX)"
    tar -xzf "$tmp_archive" -C "$tmp_extract"

    # کپی فایل باینری و کتابخانه‌ها به دایرکتوری اصلی (حفظ .env و data/)
    cp -r "$tmp_extract"/* "$target_dir"/ 2>/dev/null || true
    chmod +x "$target_dir"/main.bin 2>/dev/null || chmod +x "$target_dir"/main 2>/dev/null || true

    rm -rf "$tmp_extract" "$tmp_archive"

    # ۴. راه‌اندازی مجدد سرویس
    if [ "$systemd_was_active" = true ]; then
        log_info "راه‌اندازی مجدد سرویس سیستمی didban..."
        if [ "$(id -u)" -eq 0 ]; then
            systemctl start didban
        else
            sudo systemctl start didban
        fi
    fi

    log_ok "به‌روزرسانی با موفقیت به پایان رسید! 🎉"
}

main() {
    print_header
    check_dependencies

    local default_dir
    default_dir="$(get_default_install_dir)"

    echo -e "${CLR_BOLD}مرحله ۱: تعیین مسیر نصب${CLR_RESET}"
    local target_dir
    target_dir="$(prompt_input "مسیر نصب برنامه را وارد کنید" "$default_dir")"
    target_dir="${target_dir/#\~/$HOME}" # بسط ~ به خانه کاربر

    # بررسی اینکه آیا قبلاً نصب شده است
    if [ -f "${target_dir}/main.bin" ] || [ -f "${target_dir}/main" ]; then
        echo ""
        log_warn "سامانه دیدبان پیش‌تر در مسیر '${target_dir}' شناسایی شد."
        local do_update
        do_update="$(prompt_input "آیا می‌خواهید سامانه را به آخرین نسخه به‌روزرسانی (Update) کنید؟ (y/n)" "y")"
        if [[ "$do_update" =~ ^[Yy]$ ]]; then
            update_didban "$target_dir"
            exit 0
        fi
        log_info "ادامه مراحل نصب مجدد..."
    fi

    echo ""
    echo -e "${CLR_BOLD}مرحله ۲: دریافت و استخراج بسته دیدبان${CLR_RESET}"
    mkdir -p "$target_dir"

    local tmp_archive
    tmp_archive="$(mktemp /tmp/didban_install_XXXXXX.tar.gz)"
    log_info "در حال دانلود بسته رسمی لینوکس (didban-linux-x86_64.tar.gz)..."
    if ! download_file "$LATEST_URL" "$tmp_archive"; then
        log_err "خطا در دانلود بسته! لطفاً اتصال اینترنت خود را بررسی نمایید."
        rm -f "$tmp_archive"
        exit 1
    fi

    log_info "در حال استخراج بسته در مسیر ${target_dir}..."
    tar -xzf "$tmp_archive" -C "$target_dir"
    rm -f "$tmp_archive"

    # اطمینان از دسترسی اجرایی به باینری
    local bin_path="${target_dir}/main.bin"
    if [ ! -f "$bin_path" ] && [ -f "${target_dir}/main" ]; then
        bin_path="${target_dir}/main"
    fi
    chmod +x "$bin_path"

    # ایجاد پوشه data
    mkdir -p "${target_dir}/data"
    log_ok "بسته با موفقیت در محل مورد نظر مستقر شد."

    echo ""
    echo -e "${CLR_BOLD}مرحله ۳: پیکربندی امنیتی و مشخصات مدیر${CLR_RESET}"

    local admin_user
    admin_user="$(prompt_input "نام کاربری مدیر سیستم" "admin")"

    local web_port
    web_port="$(prompt_input "پورت سرویس وب دیدبان" "23456")"

    local admin_pass=""
    local admin_pass_confirm=""
    while true; do
        admin_pass="$(prompt_secret "کلمه عبور دلخواه مدیر را وارد کنید")"
        if [ -z "$admin_pass" ]; then
            log_err "کلمه عبور نمی‌تواند خالی باشد!"
            continue
        fi

        admin_pass_confirm="$(prompt_secret "مجدداً کلمه عبور را وارد کنید")"
        if [ "$admin_pass" != "$admin_pass_confirm" ]; then
            log_err "کلمه‌های عبور وارد شده یکسان نیستند. لطفاً مجدداً امتحان کنید."
            continue
        fi
        break
    done

    log_info "تولید هش امن کلمه عبور با موتور رمزنگاری داخلی دیدبان..."
    local hash_output
    hash_output="$("$bin_path" --hash-password "$admin_pass" 2>/dev/null || true)"
    
    local hashed_value
    hashed_value="$(echo "$hash_output" | grep -E '^ADMIN_PASS=' | head -n1 | cut -d'=' -f2-)"

    if [ -z "$hashed_value" ]; then
        log_warn "تولید خودکار هش با موتور باینری انجام نشد. از کلمه عبور ورودی استفاده می‌شود."
        hashed_value="$admin_pass"
    else
        log_ok "هش امن کلمه عبور با موفقیت تولید شد."
    fi

    # ایجاد فایل .env
    local env_file="${target_dir}/.env"
    cat <<EOF > "$env_file"
ADMIN_USER=${admin_user}
ADMIN_PASS=${hashed_value}
PORT=${web_port}
HOST=0.0.0.0
EOF
    chmod 600 "$env_file"
    log_ok "فایل تنظیمات امنیتی (.env) ایجاد شد."

    # پیشنهاد نصب اختیاری FFmpeg برای لایو استریم
    suggest_install_ffmpeg

    echo ""
    echo -e "${CLR_BOLD}مرحله ۴: سرویس‌دهی پس‌زمینه (Systemd)${CLR_RESET}"
    local setup_systemd
    setup_systemd="$(prompt_input "آیا مایل به راه‌اندازی دیدبان به عنوان سرویس خودکار پس‌زمینه (Systemd) هستید؟ (y/n)" "y")"

    if [[ "$setup_systemd" =~ ^[Yy]$ ]]; then
        local run_user
        run_user="$(id -un)"
        if [ "$(id -u)" -eq 0 ]; then
            # اگر با روت اجرا شده اما مسیر خانگی کاربر دیگر است
            if [[ "$target_dir" =~ ^/home/([^/]+) ]]; then
                run_user="${BASH_REMATCH[1]}"
            fi
        fi

        local service_file="/etc/systemd/system/didban.service"
        local service_content="[Unit]
Description=Didban CCTV Monitoring Service
After=network.target

[Service]
Type=simple
User=${run_user}
WorkingDirectory=${target_dir}
ExecStart=${bin_path}
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target"

        local can_write=false
        if [ "$(id -u)" -eq 0 ]; then
            echo "$service_content" > "$service_file"
            can_write=true
        elif command -v sudo &>/dev/null; then
            echo "$service_content" | sudo tee "$service_file" > /dev/null
            can_write=true
        fi

        if [ "$can_write" = true ]; then
            if [ "$(id -u)" -eq 0 ]; then
                systemctl daemon-reload
                systemctl enable --now didban.service
            else
                sudo systemctl daemon-reload
                sudo systemctl enable --now didban.service
            fi
            log_ok "سرویس didban.service با موفقیت ثبت، فعال و اجرا شد."
        else
            log_warn "دسترسی روت جهت ایجاد سرویس systemd مهیا نبود. فایل سرویس ایجاد نشد."
        fi
    fi

    # تشخیص آی‌پی سرور برای نمایش
    local server_ip
    server_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -n1 || echo "IP_SERVER")"

    echo ""
    echo -e "${CLR_GREEN}═══════════════════════════════════════════════════════════════${CLR_RESET}"
    echo -e " ${CLR_GREEN}🎉 نصب و راه‌اندازی سامانه دیدبان با موفقیت به پایان رسید!${CLR_RESET}"
    echo -e "${CLR_GREEN}═══════════════════════════════════════════════════════════════${CLR_RESET}"
    echo ""
    echo -e "  🌐 ${CLR_BOLD}آدرس پنل مدیریت تحت وب:${CLR_RESET}"
    echo -e "     ${CLR_CYAN}http://${server_ip}:${web_port}${CLR_RESET}  یا  ${CLR_CYAN}http://localhost:${web_port}${CLR_RESET}"
    echo ""
    echo -e "  👤 ${CLR_BOLD}نام کاربری:${CLR_RESET} ${CLR_YELLOW}${admin_user}${CLR_RESET}"
    echo -e "  📁 ${CLR_BOLD}پوشه نصب:${CLR_RESET}   ${target_dir}"
    echo ""
    echo -e "  ⚙️ ${CLR_BOLD}دستورات مدیریت دستی:${CLR_RESET}"
    if command -v systemctl &>/dev/null && [ -f "/etc/systemd/system/didban.service" ]; then
        echo -e "     وضعیت سرویس:  ${CLR_DIM}sudo systemctl status didban${CLR_RESET}"
        echo -e "     توقف سرویس:   ${CLR_DIM}sudo systemctl stop didban${CLR_RESET}"
        echo -e "     شروع مجدد:     ${CLR_DIM}sudo systemctl restart didban${CLR_RESET}"
        echo -e "     مشاهده لاگ‌ها:  ${CLR_DIM}journalctl -u didban -f${CLR_RESET}"
    else
        echo -e "     اجرای دستی:   ${CLR_DIM}cd ${target_dir} && ./main.bin${CLR_RESET}"
    fi
    echo ""
    echo -e "  🔄 ${CLR_BOLD}به‌روزرسانی به نسخه‌های جدید در آینده:${CLR_RESET}"
    echo -e "     کافی است همین دستور نصب را مجدداً اجرا فرمایید تا گزینه Update فعال گردد."
    echo -e "${CLR_GREEN}═══════════════════════════════════════════════════════════════${CLR_RESET}"
}

main "$@"
