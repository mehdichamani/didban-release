#!/usr/bin/env bash
# ==============================================================================
# 🛡️ Didban CCTV Monitoring System
# Interactive Installer & Updater for Linux
# ==============================================================================
set -euo pipefail

# Ensure standard UTF-8 locale environment
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 2>/dev/null || true
export LANG=C.UTF-8 2>/dev/null || export LANG=en_US.UTF-8 2>/dev/null || true

REPO_RELEASE="mehdichamani/didban-release"
LATEST_URL="https://github.com/${REPO_RELEASE}/releases/latest/download/didban-linux-x86_64.tar.gz"

# Colors for terminal output
CLR_RESET="\033[0m"
CLR_RED="\033[1;31m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_BLUE="\033[1;34m"
CLR_CYAN="\033[1;36m"
CLR_BOLD="\033[1m"
CLR_DIM="\033[2m"

# Default language: en (English)
LANG_MODE="en"

select_language() {
    echo -e "${CLR_CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║        🛡️ Didban CCTV Monitoring System / سامانه دیدبان       ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${CLR_RESET}"

    echo -e "Persian rendering check / بررسی خوانایی فونت فارسی:"
    echo -e "  [ ${CLR_BOLD}متن آزمایشی فارسی: دیدبان سیستم نظارت${CLR_RESET} ]\n"
    echo -e "Press [${CLR_GREEN}Enter${CLR_RESET}] to continue in English (Recommended for remote/headless)"
    echo -e "Or press [${CLR_YELLOW}F${CLR_RESET}] then Enter for Persian (فارسی)\n"
    echo -ne "Choice / انتخاب [${CLR_GREEN}English${CLR_RESET}]: " > /dev/tty

    local choice=""
    read -r choice < /dev/tty || true
    if [[ "$choice" =~ ^[Ff]$ ]]; then
        LANG_MODE="fa"
    else
        LANG_MODE="en"
    fi
}

print_header() {
    echo -e "${CLR_CYAN}"
    if [ "$LANG_MODE" = "fa" ]; then
        echo "  ╔═══════════════════════════════════════════════════════════════╗"
        echo "  ║        🛡️ سامانه پایش و مانیتورینگ دوربین دیدبان (Didban)     ║"
        echo "  ║           اسکریپت نصب و به‌روزرسانی سریع و هوشمند            ║"
        echo "  ╚═══════════════════════════════════════════════════════════════╝"
    else
        echo "  ╔═══════════════════════════════════════════════════════════════╗"
        echo "  ║             🛡️ Didban CCTV Monitoring System                  ║"
        echo "  ║        Fast & Automated Linux Installer & Updater             ║"
        echo "  ╚═══════════════════════════════════════════════════════════════╝"
    fi
    echo -e "${CLR_RESET}"
}

log_info() {
    local label="[INFO]"
    [ "$LANG_MODE" = "fa" ] && label="[اطلاع]"
    echo -e " ${CLR_BLUE}●${CLR_RESET} ${CLR_BOLD}${label}${CLR_RESET} $1"
}

log_ok() {
    local label="[OK]"
    [ "$LANG_MODE" = "fa" ] && label="[موفق]"
    echo -e " ${CLR_GREEN}✔${CLR_RESET} ${CLR_BOLD}${label}${CLR_RESET} $1"
}

log_warn() {
    local label="[WARN]"
    [ "$LANG_MODE" = "fa" ] && label="[هشدار]"
    echo -e " ${CLR_YELLOW}▲${CLR_RESET} ${CLR_BOLD}${label}${CLR_RESET} $1"
}

log_err() {
    local label="[ERROR]"
    [ "$LANG_MODE" = "fa" ] && label="[خطا]"
    echo -e " ${CLR_RED}✖${CLR_RESET} ${CLR_BOLD}${label}${CLR_RESET} $1" >&2
}

# Interactive prompt compatible with curl ... | bash
prompt_input() {
    local prompt_en="$1"
    local prompt_fa="$2"
    local default_val="$3"
    local prompt_msg="$prompt_en"
    if [ "$LANG_MODE" = "fa" ] && [ -n "$prompt_fa" ]; then
        prompt_msg="$prompt_fa"
    fi

    local result=""
    if [ -n "$default_val" ]; then
        echo -ne " ${CLR_CYAN}?${CLR_RESET} ${prompt_msg} [${CLR_YELLOW}${default_val}${CLR_RESET}]: " > /dev/tty
    else
        echo -ne " ${CLR_CYAN}?${CLR_RESET} ${prompt_msg}: " > /dev/tty
    fi

    read -r result < /dev/tty || true
    if [ -z "$result" ]; then
        echo "$default_val"
    else
        echo "$result"
    fi
}

prompt_secret() {
    local prompt_en="$1"
    local prompt_fa="$2"
    local prompt_msg="$prompt_en"
    if [ "$LANG_MODE" = "fa" ] && [ -n "$prompt_fa" ]; then
        prompt_msg="$prompt_fa"
    fi

    local result=""
    echo -ne " ${CLR_CYAN}🔒${CLR_RESET} ${prompt_msg}: " > /dev/tty
    read -r -s result < /dev/tty || true
    echo "" > /dev/tty
    echo "$result"
}

check_dependencies() {
    local missing=()
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        missing+=("curl or wget")
    fi
    if ! command -v tar &>/dev/null; then
        missing+=("tar")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        if [ "$LANG_MODE" = "fa" ]; then
            log_err "پیش‌نیازهای زیر یافت نشدند: ${missing[*]}"
            log_info "لطفاً ابتدا آنها را با مدیر بسته سیستم خود (apt/dnf/pacman) نصب کنید."
        else
            log_err "Missing dependencies: ${missing[*]}"
            log_info "Please install them via your system package manager (apt/dnf/pacman)."
        fi
        exit 1
    fi
}

suggest_install_ffmpeg() {
    echo ""
    if [ "$LANG_MODE" = "fa" ]; then
        echo -e "${CLR_BOLD}قابلیت جانبی: پخش زنده تصاویر (Live RTSP Stream via FFmpeg)${CLR_RESET}"
        if command -v ffmpeg &>/dev/null; then
            log_ok "ابزار FFmpeg روی سیستم شناسایی شد (قابلیت پخش زنده فعال است)."
            return 0
        fi

        log_warn "ابزار FFmpeg شناسایی نشد."
        log_info "سامانه دیدبان بدون FFmpeg به طور کامل کار می‌کند (پایش وضعیت، دیتابیس، پنل وب و اسنپ‌شات‌ها فعالند)."
        log_info "ابزار FFmpeg صرفاً جهت پخش زنده جریان دوربین‌ها در مرورگر (Live Stream) کاربرد دارد."

        local want_ffmpeg
        want_ffmpeg="$(prompt_input "Install FFmpeg automatically? (y/n)" "آیا مایل به نصب خودکار ابزار FFmpeg هستید؟ (y/n)" "n")"
        if [[ ! "$want_ffmpeg" =~ ^[Yy]$ ]]; then
            log_info "از نصب FFmpeg صرف‌نظر شد. در صورت نیاز می‌توانید آن را در آینده نصب کنید."
            return 0
        fi
        log_info "تلاش برای نصب سریع FFmpeg با مدیر بسته‌های سیستم..."
    else
        echo -e "${CLR_BOLD}Optional Feature: Live Video Streaming (Live RTSP Stream via FFmpeg)${CLR_RESET}"
        if command -v ffmpeg &>/dev/null; then
            log_ok "FFmpeg detected on system (Live streaming is enabled)."
            return 0
        fi

        log_warn "FFmpeg is not installed."
        log_info "Didban works 100% without FFmpeg (Status monitoring, DB, Web UI, and Snapshots are fully functional)."
        log_info "FFmpeg is only needed for live browser video streaming."

        local want_ffmpeg
        want_ffmpeg="$(prompt_input "Install FFmpeg automatically? (y/n)" "" "n")"
        if [[ ! "$want_ffmpeg" =~ ^[Yy]$ ]]; then
            log_info "Skipped FFmpeg installation. You can install it anytime later."
            return 0
        fi
        log_info "Attempting FFmpeg installation via package manager..."
    fi

    local installed=false
    if command -v apt-get &>/dev/null; then
        [ "$LANG_MODE" = "fa" ] && log_info "سیستم‌عامل دبیان/اوبونتو شناسایی شد (apt-get)..." || log_info "Debian/Ubuntu detected (apt-get)..."
        if [ "$(id -u)" -eq 0 ]; then
            apt-get update -y && apt-get install -y ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo apt-get update -y && sudo apt-get install -y ffmpeg && installed=true || true
        fi
    elif command -v pacman &>/dev/null; then
        [ "$LANG_MODE" = "fa" ] && log_info "سیستم‌عامل آرچ لینوکس شناسایی شد (pacman)..." || log_info "Arch Linux detected (pacman)..."
        if [ "$(id -u)" -eq 0 ]; then
            pacman -Sy --noconfirm ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo pacman -Sy --noconfirm ffmpeg && installed=true || true
        fi
    elif command -v dnf &>/dev/null; then
        [ "$LANG_MODE" = "fa" ] && log_info "سیستم‌عامل RHEL/Fedora/Rocky شناسایی شد (dnf)..." || log_info "Fedora/RHEL detected (dnf)..."
        if [ "$(id -u)" -eq 0 ]; then
            dnf install -y ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo dnf install -y ffmpeg && installed=true || true
        fi
    elif command -v yum &>/dev/null; then
        [ "$LANG_MODE" = "fa" ] && log_info "سیستم‌عامل CentOS/RHEL شناسایی شد (yum)..." || log_info "CentOS/RHEL detected (yum)..."
        if [ "$(id -u)" -eq 0 ]; then
            yum install -y ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo yum install -y ffmpeg && installed=true || true
        fi
    elif command -v zypper &>/dev/null; then
        [ "$LANG_MODE" = "fa" ] && log_info "سیستم‌عامل openSUSE شناسایی شد (zypper)..." || log_info "openSUSE detected (zypper)..."
        if [ "$(id -u)" -eq 0 ]; then
            zypper --non-interactive install ffmpeg && installed=true || true
        elif command -v sudo &>/dev/null; then
            sudo zypper --non-interactive install ffmpeg && installed=true || true
        fi
    fi

    if [ "$installed" = true ] && command -v ffmpeg &>/dev/null; then
        if [ "$LANG_MODE" = "fa" ]; then
            log_ok "ابزار FFmpeg با موفقیت روی سرور نصب و فعال شد."
        else
            log_ok "FFmpeg installed successfully."
        fi
    else
        if [ "$LANG_MODE" = "fa" ]; then
            log_warn "نصب خودکار FFmpeg به دلیل عدم دسترسی روت یا تفاوت مخازن انجام نشد."
            log_info "می‌توانید آن را به صورت دستی یا از وب‌سایت رسمی دریافت نمایید:"
            log_info "🔗 صفحه رسمی دانلود FFmpeg: https://ffmpeg.org/download.html"
        else
            log_warn "Automatic FFmpeg installation could not be completed."
            log_info "You can install it manually or download static binaries:"
            log_info "🔗 FFmpeg Download Page: https://ffmpeg.org/download.html"
        fi
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

get_default_install_dir() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "/opt/didban"
    else
        echo "${HOME}/didban"
    fi
}

update_didban() {
    local target_dir="$1"
    if [ "$LANG_MODE" = "fa" ]; then
        log_info "در حال آماده‌سازی برای به‌روزرسانی سامانه در: ${CLR_BOLD}${target_dir}${CLR_RESET}"
    else
        log_info "Preparing to update Didban at: ${CLR_BOLD}${target_dir}${CLR_RESET}"
    fi

    # 1. Stop service if running
    local systemd_was_active=false
    if command -v systemctl &>/dev/null && systemctl is-active --quiet didban 2>/dev/null; then
        if [ "$LANG_MODE" = "fa" ]; then
            log_info "متوقف‌سازی سرویس didban جهت اعمال به‌روزرسانی..."
        else
            log_info "Stopping didban service for update..."
        fi
        if [ "$(id -u)" -eq 0 ]; then
            systemctl stop didban
        else
            sudo systemctl stop didban
        fi
        systemd_was_active=true
    fi

    # Stop standalone processes if running
    pkill -f "${target_dir}/main.bin" 2>/dev/null || true

    # 2. Download latest release
    local tmp_archive
    tmp_archive="$(mktemp /tmp/didban_update_XXXXXX.tar.gz)"
    if [ "$LANG_MODE" = "fa" ]; then
        log_info "در حال دریافت آخرین نسخه از مخزن رسمی دیدبان..."
    else
        log_info "Downloading latest release package..."
    fi

    if ! download_file "$LATEST_URL" "$tmp_archive"; then
        if [ "$LANG_MODE" = "fa" ]; then
            log_err "دانلود بسته با شکست مواجه شد. لطفاً اتصال اینترنت خود را بررسی کنید."
        else
            log_err "Download failed. Please check your internet connection."
        fi
        rm -f "$tmp_archive"
        exit 1
    fi

    # 3. Extract and update binaries without touching .env or data/
    if [ "$LANG_MODE" = "fa" ]; then
        log_info "در حال استخراج و جایگزینی فایل‌های جدید..."
    else
        log_info "Extracting and updating binary files..."
    fi
    local tmp_extract
    tmp_extract="$(mktemp -d /tmp/didban_ext_XXXXXX)"
    tar -xzf "$tmp_archive" -C "$tmp_extract"

    cp -r "$tmp_extract"/* "$target_dir"/ 2>/dev/null || true
    chmod +x "$target_dir"/main.bin 2>/dev/null || chmod +x "$target_dir"/main 2>/dev/null || true

    rm -rf "$tmp_extract" "$tmp_archive"

    # 4. Restart service
    if [ "$systemd_was_active" = true ]; then
        if [ "$LANG_MODE" = "fa" ]; then
            log_info "راه‌اندازی مجدد سرویس سیستمی didban..."
        else
            log_info "Restarting didban system service..."
        fi
        if [ "$(id -u)" -eq 0 ]; then
            systemctl start didban
        else
            sudo systemctl start didban
        fi
    fi

    if [ "$LANG_MODE" = "fa" ]; then
        log_ok "به‌روزرسانی با موفقیت به پایان رسید! 🎉"
    else
        log_ok "Update completed successfully! 🎉"
    fi
}

main() {
    select_language
    print_header
    check_dependencies

    local default_dir
    default_dir="$(get_default_install_dir)"

    if [ "$LANG_MODE" = "fa" ]; then
        echo -e "${CLR_BOLD}مرحله ۱: تعیین مسیر نصب${CLR_RESET}"
    else
        echo -e "${CLR_BOLD}Step 1: Choose Installation Directory${CLR_RESET}"
    fi

    local target_dir
    target_dir="$(prompt_input "Enter installation path" "مسیر نصب برنامه را وارد کنید" "$default_dir")"
    target_dir="${target_dir/#\~/$HOME}"

    # Check if already installed
    if [ -f "${target_dir}/main.bin" ] || [ -f "${target_dir}/main" ]; then
        echo ""
        if [ "$LANG_MODE" = "fa" ]; then
            log_warn "سامانه دیدبان پیش‌تر در مسیر '${target_dir}' شناسایی شد."
        else
            log_warn "Didban installation detected at '${target_dir}'."
        fi

        local do_update
        do_update="$(prompt_input "Update existing installation to latest version? (y/n)" "آیا می‌خواهید سامانه را به آخرین نسخه به‌روزرسانی (Update) کنید؟ (y/n)" "y")"
        if [[ "$do_update" =~ ^[Yy]$ ]]; then
            update_didban "$target_dir"
            exit 0
        fi
        [ "$LANG_MODE" = "fa" ] && log_info "ادامه مراحل نصب مجدد..." || log_info "Proceeding with fresh setup..."
    fi

    echo ""
    if [ "$LANG_MODE" = "fa" ]; then
        echo -e "${CLR_BOLD}مرحله ۲: دریافت و استخراج بسته دیدبان${CLR_RESET}"
    else
        echo -e "${CLR_BOLD}Step 2: Download & Extract Didban Package${CLR_RESET}"
    fi
    mkdir -p "$target_dir"

    local tmp_archive
    tmp_archive="$(mktemp /tmp/didban_install_XXXXXX.tar.gz)"
    if [ "$LANG_MODE" = "fa" ]; then
        log_info "در حال دانلود بسته رسمی لینوکس (didban-linux-x86_64.tar.gz)..."
    else
        log_info "Downloading official Linux package (didban-linux-x86_64.tar.gz)..."
    fi

    if ! download_file "$LATEST_URL" "$tmp_archive"; then
        if [ "$LANG_MODE" = "fa" ]; then
            log_err "خطا در دانلود بسته! لطفاً اتصال اینترنت خود را بررسی نمایید."
        else
            log_err "Download failed! Please check your internet connection."
        fi
        rm -f "$tmp_archive"
        exit 1
    fi

    if [ "$LANG_MODE" = "fa" ]; then
        log_info "در حال استخراج بسته در مسیر ${target_dir}..."
    else
        log_info "Extracting bundle to ${target_dir}..."
    fi
    tar -xzf "$tmp_archive" -C "$target_dir"
    rm -f "$tmp_archive"

    local bin_path="${target_dir}/main.bin"
    if [ ! -f "$bin_path" ] && [ -f "${target_dir}/main" ]; then
        bin_path="${target_dir}/main"
    fi
    chmod +x "$bin_path"

    mkdir -p "${target_dir}/data"
    if [ "$LANG_MODE" = "fa" ]; then
        log_ok "بسته با موفقیت در محل مورد نظر مستقر شد."
    else
        log_ok "Package extracted successfully."
    fi

    echo ""
    if [ "$LANG_MODE" = "fa" ]; then
        echo -e "${CLR_BOLD}مرحله ۳: پیکربندی امنیتی و مشخصات مدیر${CLR_RESET}"
    else
        echo -e "${CLR_BOLD}Step 3: Security & Administrator Credentials${CLR_RESET}"
    fi

    local admin_user
    admin_user="$(prompt_input "Admin username" "نام کاربری مدیر سیستم" "admin")"

    local web_port
    web_port="$(prompt_input "Web service port" "پورت سرویس وب دیدبان" "23456")"

    local admin_pass=""
    local admin_pass_confirm=""
    while true; do
        admin_pass="$(prompt_secret "Enter admin password" "کلمه عبور دلخواه مدیر را وارد کنید")"
        if [ -z "$admin_pass" ]; then
            [ "$LANG_MODE" = "fa" ] && log_err "کلمه عبور نمی‌تواند خالی باشد!" || log_err "Password cannot be empty!"
            continue
        fi

        admin_pass_confirm="$(prompt_secret "Confirm admin password" "مجدداً کلمه عبور را وارد کنید")"
        if [ "$admin_pass" != "$admin_pass_confirm" ]; then
            [ "$LANG_MODE" = "fa" ] && log_err "کلمه‌های عبور وارد شده یکسان نیستند. لطفاً مجدداً امتحان کنید." || log_err "Passwords do not match. Please try again."
            continue
        fi
        break
    done

    if [ "$LANG_MODE" = "fa" ]; then
        log_info "تولید هش امن کلمه عبور با موتور رمزنگاری داخلی دیدبان..."
    else
        log_info "Generating secure password hash via Didban internal engine..."
    fi

    local hash_output
    hash_output="$("$bin_path" --hash-password "$admin_pass" 2>/dev/null || true)"
    
    local hashed_value
    hashed_value="$(echo "$hash_output" | grep -E '^ADMIN_PASS=' | head -n1 | cut -d'=' -f2-)"

    if [ -z "$hashed_value" ]; then
        if [ "$LANG_MODE" = "fa" ]; then
            log_warn "تولید خودکار هش با موتور باینری انجام نشد. از کلمه عبور ورودی استفاده می‌شود."
        else
            log_warn "Hashing binary was bypassed. Using raw password in .env."
        fi
        hashed_value="$admin_pass"
    else
        [ "$LANG_MODE" = "fa" ] && log_ok "هش امن کلمه عبور با موفقیت تولید شد." || log_ok "Secure password hash generated."
    fi

    # Create .env file
    local env_file="${target_dir}/.env"
    cat <<EOF > "$env_file"
ADMIN_USER=${admin_user}
ADMIN_PASS=${hashed_value}
PORT=${web_port}
HOST=0.0.0.0
EOF
    chmod 600 "$env_file"
    [ "$LANG_MODE" = "fa" ] && log_ok "فایل تنظیمات امنیتی (.env) ایجاد شد." || log_ok "Configuration file (.env) saved."

    # Suggest optional FFmpeg
    suggest_install_ffmpeg

    echo ""
    if [ "$LANG_MODE" = "fa" ]; then
        echo -e "${CLR_BOLD}مرحله ۴: سرویس‌دهی پس‌زمینه (Systemd)${CLR_RESET}"
    else
        echo -e "${CLR_BOLD}Step 4: Background Service (Systemd)${CLR_RESET}"
    fi

    local setup_systemd
    setup_systemd="$(prompt_input "Configure Didban as a systemd background service? (y/n)" "آیا مایل به راه‌اندازی دیدبان به عنوان سرویس خودکار پس‌زمینه (Systemd) هستید؟ (y/n)" "y")"

    if [[ "$setup_systemd" =~ ^[Yy]$ ]]; then
        local run_user
        run_user="$(id -un)"
        if [ "$(id -u)" -eq 0 ]; then
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
            if [ "$LANG_MODE" = "fa" ]; then
                log_ok "سرویس didban.service با موفقیت ثبت، فعال و اجرا شد."
            else
                log_ok "didban.service enabled and started successfully."
            fi
        else
            if [ "$LANG_MODE" = "fa" ]; then
                log_warn "دسترسی روت جهت ایجاد سرویس systemd مهیا نبود. فایل سرویس ایجاد نشد."
            else
                log_warn "Root/sudo privileges not available. Skipped systemd configuration."
            fi
        fi
    fi

    local server_ip
    server_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -n1 || echo "IP_SERVER")"

    echo ""
    echo -e "${CLR_GREEN}═══════════════════════════════════════════════════════════════${CLR_RESET}"
    if [ "$LANG_MODE" = "fa" ]; then
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
    else
        echo -e " ${CLR_GREEN}🎉 Didban setup completed successfully!${CLR_RESET}"
        echo -e "${CLR_GREEN}═══════════════════════════════════════════════════════════════${CLR_RESET}"
        echo ""
        echo -e "  🌐 ${CLR_BOLD}Web Dashboard URL:${CLR_RESET}"
        echo -e "     ${CLR_CYAN}http://${server_ip}:${web_port}${CLR_RESET}  or  ${CLR_CYAN}http://localhost:${web_port}${CLR_RESET}"
        echo ""
        echo -e "  👤 ${CLR_BOLD}Admin User:${CLR_RESET}  ${CLR_YELLOW}${admin_user}${CLR_RESET}"
        echo -e "  📁 ${CLR_BOLD}Install Dir:${CLR_RESET} ${target_dir}"
        echo ""
        echo -e "  ⚙️ ${CLR_BOLD}Service Commands:${CLR_RESET}"
        if command -v systemctl &>/dev/null && [ -f "/etc/systemd/system/didban.service" ]; then
            echo -e "     Status:   ${CLR_DIM}sudo systemctl status didban${CLR_RESET}"
            echo -e "     Stop:     ${CLR_DIM}sudo systemctl stop didban${CLR_RESET}"
            echo -e "     Restart:  ${CLR_DIM}sudo systemctl restart didban${CLR_RESET}"
            echo -e "     Logs:     ${CLR_DIM}journalctl -u didban -f${CLR_RESET}"
        else
            echo -e "     Run manually: ${CLR_DIM}cd ${target_dir} && ./main.bin${CLR_RESET}"
        fi
        echo ""
        echo -e "  🔄 ${CLR_BOLD}Future Updates:${CLR_RESET}"
        echo -e "     Simply re-run the install one-liner to check and apply updates."
    fi
    echo -e "${CLR_GREEN}═══════════════════════════════════════════════════════════════${CLR_RESET}"
}

main "$@"
