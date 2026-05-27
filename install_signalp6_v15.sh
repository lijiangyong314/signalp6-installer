#!/bin/bash
# ============================================================
# SignalP 6.0 全自动安装脚本（v15 双语发布版）
# SignalP 6.0 Fully Automated Installer (v15 Bilingual Release)
# ============================================================
#
# v15 新增 / v15 new features:
#   - 断点续装 / Checkpoint resume (中断后可继续安装)
#   - Conda 缺失自动检测 + 交互式安装 / Auto-detect + install Miniconda
#   - 幂等步骤设计 / Idempotent steps (已完成步骤自动跳过)
#   - --reset 参数强制重新安装 / --reset flag for fresh install
#
# 支持模式 / Supported modes:
#   fast            快速模式 - 蒸馏模型，速度最快
#   slow-sequential 慢速顺序模式 - 最高精度，逐条处理
#
# 用法 / Usage:
#   ./install_signalp6_v15.sh                    # 交互选择 / Interactive mode selection
#   ./install_signalp6_v15.sh -m fast            # 指定 fast 模式 / Specify fast mode
#   ./install_signalp6_v15.sh -m slow-sequential # 指定 slow-sequential
#   ./install_signalp6_v15.sh -m all            # 安装所有可用模式 / Install all available modes
#   ./install_signalp6_v15.sh --reset           # 强制重新安装 / Force fresh install
#   ./install_signalp6_v15.sh -h                # 查看帮助 / Show help
#
# ============================================================

set -uo pipefail

# 提前声明，避免 set -u 报 "未绑定的变量" / Pre-declare to avoid nounset errors
TARGET_MODES=()
CONDA_BASE=""

WORK_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)"

# ================================================================
#  ★ 版本配置区 / Version Configuration
#  SignalP 更新时只需修改此处 / Only modify here when SignalP updates
# ================================================================
PYTHON_VERSION="3.7"          # Python 版本 / Python version
PYTORCH_VERSION="1.8.1"       # PyTorch 版本 / PyTorch version
TORCHVISION_VERSION="0.9.1"   # TorchVision 版本 / TorchVision version
TORCH_VARIANT="cpu"           # cpu 或 cu111 等 / cpu or cu111 etc.

# 依赖版本约束 / Dependency version constraints
NUMPY_CONSTRAINT=">=1.19,<2.0"
MATPLOTLIB_CONSTRAINT=">3.3.2,<5.0"
TQDM_CONSTRAINT="<4.66"
PILLOW_CONSTRAINT="<11"

# 模型文件名映射 / Model file mapping
# 如果官方更新了文件名，修改此处即可 / If filenames change, update here
declare -A MODEL_FILE_MAP=(
    ["fast"]="distilled_model_signalp6.pt"
    ["slow-sequential"]="sequential_models_signalp6"
)

declare -A MODE_DESC=(
    ["fast"]="快速模式 - 蒸馏模型，速度最快 / Fast mode - distilled model, fastest speed"
    ["slow-sequential"]="慢速顺序模式 - 最高精度，逐条处理 / Slow-sequential - highest accuracy, sequential processing"
)

ALL_MODES=("fast" "slow-sequential")

# ================================================================
#  ★ NEW: 断点续装 - 状态文件管理 / Checkpoint Resume - State File
# ================================================================
STATE_FILE="$HOME/.signalp6_install_state"

save_state() {
    local step="$1"
    local modes_str=""
    if [ ${#TARGET_MODES[@]} -gt 0 ] 2>/dev/null; then
        modes_str=$(IFS='|'; echo "${TARGET_MODES[*]}")
    fi
    # 所有值必须加双引号，否则 source 时 bash 会把 | 解释为管道、空格后的内容当命令
    # All values MUST be double-quoted, otherwise source treats | as pipe and spaces as cmd separators
    printf 'CURRENT_STEP="%s"\nTARGET_MODES="%s"\nCONDA_BASE="%s"\nSCRIPT_VERSION="v15"\nTIMESTAMP="%s"\n' \
        "$step" "${modes_str}" "${CONDA_BASE:-}" "$(date '+%Y-%m-%d %H:%M:%S')" > "$STATE_FILE"
}

load_state() {
    [ ! -f "$STATE_FILE" ] && return 1
    # 用 grep+sed 安全解析，避免 source 的 shell 注入风险
    # Use grep+sed to safely parse, avoid source's shell injection risk
    CURRENT_STEP=$(grep '^CURRENT_STEP=' "$STATE_FILE" | sed 's/^CURRENT_STEP=//' | tr -d '"')
    TARGET_MODES=$(grep '^TARGET_MODES=' "$STATE_FILE" | sed 's/^TARGET_MODES=//' | tr -d '"')
    CONDA_BASE=$(grep '^CONDA_BASE=' "$STATE_FILE" | sed 's/^CONDA_BASE=//' | tr -d '"')
    TIMESTAMP=$(grep '^TIMESTAMP=' "$STATE_FILE" | sed 's/^TIMESTAMP=//' | tr -d '"')
    # Convert TARGET_MODES string to array (pipe-delimited)
    if [ -n "${TARGET_MODES:-}" ]; then
        IFS='|' read -ra TARGET_MODES <<< "$TARGET_MODES"
    fi
    # Keep a string copy for display (use [*] to get ALL elements)
    TARGET_MODES_STR="${TARGET_MODES[*]}"
    return 0
}

clear_state() {
    rm -f "$STATE_FILE"
}

step_display_name() {
    local step="$1"
    case "$step" in
        0)   echo "初始化 Conda / Init Conda" ;;
        1)   echo "创建 Python 环境 / Create Python env" ;;
        2)   echo "查找压缩包 / Find packages" ;;
        3)   echo "解压安装包 / Extract packages" ;;
        4)   echo "编译安装 / Build & install" ;;
        5a)  echo "安装 Pillow / Install Pillow" ;;
        5b)  echo "安装 matplotlib / Install matplotlib" ;;
        5c)  echo "安装 NumPy / Install NumPy" ;;
        5d)  echo "安装 PyTorch / Install PyTorch" ;;
        5e)  echo "安装 tqdm / Install tqdm" ;;
        5f)  echo "验证 signalp import / Verify signalp import" ;;
        6)   echo "部署模型权重 / Deploy model weights" ;;
        7)   echo "环境诊断 / Diagnostics" ;;
        8)   echo "最终验证 / Final verification" ;;
        *)   echo "Step $step" ;;
    esac
}

show_resume_menu() {
    local step_desc
    step_desc=$(step_display_name "${CURRENT_STEP:-?}")
    echo "" >&2
    echo "╔═══════════════════════════════════════════════════════════╗" >&2
    echo "║     检测到未完成的安装 / Previous incomplete install       ║" >&2
    echo "╠═══════════════════════════════════════════════════════════╣" >&2
    echo "║  中断位置 / Interrupted at: ${step_desc}" >&2
    echo "║  时间 / Time: ${TIMESTAMP:-?}" >&2
    echo "║  模式 / Modes: ${TARGET_MODES_STR:-?}" >&2
    echo "╚═══════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    echo "  [1] 继续上次安装 / Resume from last checkpoint" >&2
    echo "  [2] 重新安装 / Fresh install (删除已有环境重新开始)" >&2
    echo "  [3] 退出 / Exit" >&2
    echo "" >&2

    while true; do
        read -p "请选择 [1-3] / Select [1-3]: " choice >&2
        case "$choice" in
            1) return 0 ;;
            2) return 1 ;;
            3) exit 0 ;;
            *) echo "  请输入 1-3 / Please enter 1-3" >&2 ;;
        esac
    done
}

# ================================================================
#  ★ NEW: Miniconda 自动安装 / Miniconda Auto-Installer
# ================================================================
install_miniconda() {
    log_info "正在下载 Miniconda 安装程序 / Downloading Miniconda installer..."
    log_warn "  安装包约 80MB，需要联网 / ~80MB download, requires internet"
    local installer="/tmp/miniconda3_installer_$$_$(date +%s)"
    local url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"

    if command -v wget &>/dev/null; then
        wget -q --show-progress "$url" -O "$installer" 2>&1 || {
            log_error "wget 下载失败 / wget download failed"; rm -f "$installer"; return 1; }
    elif command -v curl &>/dev/null; then
        curl -fSL "$url" -o "$installer" 2>&1 || {
            log_error "curl 下载失败 / curl download failed"; rm -f "$installer"; return 1; }
    else
        log_error "未找到 wget 或 curl / Neither wget nor curl found"
        log_info "请手动安装 Miniconda: https://docs.conda.io/en/latest/miniconda.html"
        return 1
    fi

    log_info "正在安装 Miniconda 到 ~/miniconda3 / Installing Miniconda to ~/miniconda3..."
    log_warn "  这可能需要几分钟，请耐心等待 / This may take a few minutes..."
    bash "$installer" -b -p "$HOME/miniconda3" 2>&1 || {
        log_error "Miniconda 安装失败 / Miniconda installation failed"
        rm -f "$installer"; return 1; }
    rm -f "$installer"

    CONDA_BASE="$HOME/miniconda3"

    # 添加到 .bashrc（如未添加）/ Add to .bashrc if not already there
    local bashrc="${HOME}/.bashrc"
    if [ -f "$bashrc" ] && ! grep -q 'miniconda3/bin' "$bashrc" 2>/dev/null; then
        echo '' >> "$bashrc"
        echo '# >>> Miniconda3 >>>' >> "$bashrc"
        echo "export PATH=\"${HOME}/miniconda3/bin:\$PATH\"" >> "$bashrc"
        echo '# <<< Miniconda3 <<<' >> "$bashrc"
        log_info "已添加到 ~/.bashrc / Added to ~/.bashrc (新终端生效 / effective in new terminal)"
    fi

    log_info "✅ Miniconda 安装完成 / Miniconda installed: $CONDA_BASE"
    return 0
}

# ---- 工具函数 / Utility functions ----

# 所有日志输出到 stderr，避免被 $(...) 捕获
# All log output goes to stderr to avoid capture by $(...)
log_info()  { echo -e "\033[1;32m[INFO]\033[0m  $1" >&2; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $1" >&2; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; }
log_step()  { echo "" >&2; echo "===== $1 =====" >&2; }
log_skip()  { echo -e "\033[1;36m[SKIP]\033[0m  $1" >&2; }

# 格式化文件大小 / Format file size
format_size() {
    local size=$1
    if [ "$size" -ge 1073741824 ]; then
        echo "$(echo "scale=1; $size/1073741824" | bc)G"
    elif [ "$size" -ge 1048576 ]; then
        echo "$(echo "scale=1; $size/1048576" | bc)M"
    elif [ "$size" -ge 1024 ]; then
        echo "$(echo "scale=1; $size/1024" | bc)K"
    else
        echo "${size}B"
    fi
}

# ---- 从文件名解析模式和版本 / Parse mode and version from filename ----
# 支持 signalp-6.0h.fast.tar.gz 和 signalp-7.1.fast.tar.gz 等格式
# Supports signalp-6.0h.fast.tar.gz, signalp-7.1.fast.tar.gz, etc.
parse_tar_filename() {
    local filename
    filename=$(basename "$1")
    local base="${filename%.tar.gz}"
    local rest="${base#signalp-}"
    local mode_part="${rest##*.}"
    local ver="${rest%.*}"

    local mode=""
    case "$mode_part" in
        fast)                             mode="fast" ;;
        slow_sequential|slow-sequential|slowsequential) mode="slow-sequential" ;;
        *)                                mode="$mode_part" ;;
    esac

    echo "$mode $ver"
}

# ---- 查找所有 tar.gz 并智能去重 / Find all tarballs and dedup ----
find_and_dedup_tars() {
    local all_tars=()

    for d in "$HOME/桌面" "$HOME/Desktop" "$HOME/下载" "$HOME/Downloads" "$HOME" "$WORK_DIR" "/tmp" "/opt"; do
        [ -d "$d" ] || continue
        while IFS= read -r -d '' f; do
            all_tars+=("$f")
        done < <(find "$d" -maxdepth 3 -name "signalp-[0-9]*.tar.gz" -print0 2>/dev/null)
    done

    # 全盘搜索（限时 30 秒）/ Full disk search (30s timeout)
    while IFS= read -r -d '' f; do
        all_tars+=("$f")
    done < <(timeout 30 find /home -maxdepth 5 -name "signalp-[0-9]*.tar.gz" -print0 2>/dev/null || true)

    if [ ${#all_tars[@]} -eq 0 ]; then
        return 1
    fi

    # 按路径去重 / Deduplicate by path
    local unique_tars=()
    while IFS= read -r f; do
        unique_tars+=("$f")
    done < <(printf '%s\n' "${all_tars[@]}" | sort -u)

    # 解析每个文件的模式和版本 / Parse mode and version for each file
    local parse_tmp=$(mktemp)
    for tf in "${unique_tars[@]}"; do
        local parsed=$(parse_tar_filename "$tf")
        local mode=$(echo "$parsed" | awk '{print $1}')
        local ver=$(echo "$parsed" | awk '{print $2}')
        local size=$(stat -c%s "$tf" 2>/dev/null || stat -f%z "$tf" 2>/dev/null || echo 0)
        echo -e "${mode}\t${ver}\t${size}\t${tf}" >> "$parse_tmp"
    done

    # 按模式分组，每组内保留最高版本 / Group by mode, keep highest version per mode
    local dedup_tmp=$(mktemp)
    for mode in "${ALL_MODES[@]}"; do
        local best=$(grep -P "^${mode}\t" "$parse_tmp" 2>/dev/null | sort -t$'\t' -k2 -Vr | head -n1)
        if [ -n "$best" ]; then
            echo "$best" >> "$dedup_tmp"
        fi
    done

    # 检查是否有未识别模式的包 / Check for unrecognized mode packages
    grep -vP "^($(IFS='|'; echo "${ALL_MODES[*]}"))\t" "$parse_tmp" 2>/dev/null >> "$dedup_tmp" || true

    rm -f "$parse_tmp"
    echo "$dedup_tmp"
}

# ---- 交互模式选择 / Interactive mode selection ----
select_mode_with_packages() {
    local pkg_file="$1"

    echo "" >&2
    echo "========== SignalP 6.0 安装 - 请选择要安装的模式 ==========" >&2
    echo "========== SignalP 6.0 Install - Please select mode(s) ==========" >&2
    echo "" >&2

    local mode_num=1
    declare -A mode_to_num
    while IFS=$'\t' read -r mode ver size path; do
        [ -z "$mode" ] && continue
        if [[ " ${ALL_MODES[*]} " == *" ${mode} "* ]]; then
            local size_str
            size_str=$(format_size $size)
            echo "  ${mode_num}) ${mode}" >&2
            echo "       版本/Version: v${ver}  大小/Size: ${size_str}" >&2
            echo "       ${MODE_DESC[$mode]}" >&2
            echo "" >&2
            mode_to_num[$mode_num]="$mode"
            ((mode_num++))
        fi
    done < "$pkg_file"

    local all_num=$mode_num
    echo "  ${all_num}) all  - 安装以上全部可用模式 / Install all available modes above" >&2
    echo "" >&2
    echo "============================================================" >&2

    while true; do
        read -p "请选择 [1-${all_num}], 然后按回车 / Select [1-${all_num}], then press Enter: " CHOICE >&2
        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
            echo "  请输入数字！/ Please enter a number!" >&2
            continue
        fi
        if [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt $all_num ]; then
            echo "  请输入 1 到 ${all_num} 之间的数字！/ Please enter a number between 1 and ${all_num}!" >&2
            continue
        fi
        break
    done

    if [ "$CHOICE" = "$all_num" ]; then
        local result=""
        for m in "${ALL_MODES[@]}"; do
            if grep -qP "^${m}"$'\t' "$pkg_file" 2>/dev/null; then
                result="${result}${m} "
            fi
        done
        echo "$result"
    elif [ -n "${mode_to_num[$CHOICE]:-}" ]; then
        echo "${mode_to_num[$CHOICE]}"
    else
        echo ""
    fi
}

# ---- 命令行参数解析 / CLI argument parsing ----
SELECTED_MODE=""
CLI_RESET="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            SELECTED_MODE="$2"
            shift 2
            ;;
        --reset)
            CLI_RESET="true"
            shift
            ;;
        -h|--help)
            echo "用法 / Usage: $0 [-m MODE] [--reset] [-h]"
            echo ""
            echo "可用模式 / Available modes (取决于找到的压缩包 / depend on found packages):"
            for m in "${ALL_MODES[@]}"; do
                echo "  ${m}  - ${MODE_DESC[$m]}"
            done
            echo "  all    - 安装所有可用模式的模型权重 / Install all available model weights"
            echo ""
            echo "选项 / Options:"
            echo "  --reset   强制重新安装，忽略断点续装 / Force fresh install, ignore checkpoint"
            echo ""
            echo "示例 / Examples:"
            echo "  $0                     # 交互选择 / Interactive selection"
            echo "  $0 -m fast             # 安装 fast 模式 / Install fast mode"
            echo "  $0 -m slow-sequential # 安装 slow-sequential / Install slow-sequential"
            echo "  $0 -m all              # 安装所有可用模式 / Install all available"
            echo "  $0 --reset             # 强制重新安装 / Force fresh install"
            exit 0
            ;;
        *)
            log_error "未知参数 / Unknown option: $1 (使用 -h 查看帮助 / Use -h for help)"
            exit 1
            ;;
    esac
done

# ================================================================
#  ★ NEW: 断点续装入口 / Checkpoint Resume Entry Point
# ================================================================
RESUME_MODE="fresh"

if [ "$CLI_RESET" = "true" ]; then
    clear_state
    log_info "已清除安装记录，将执行全新安装 / State cleared, performing fresh install"
elif load_state; then
    if show_resume_menu; then
        # 用户选择继续 / User chose resume
        RESUME_MODE="resume"
        log_info "将从步骤 $(step_display_name "${CURRENT_STEP}") 继续安装 / Resuming from: $(step_display_name "${CURRENT_STEP}")"
        log_info "已选模式 / Selected modes: ${TARGET_MODES[*]}"
    else
        # 用户选择重新安装 / User chose fresh install
        RESUME_MODE="fresh"
        clear_state
        log_info "将执行全新安装 / Performing fresh install"
    fi
fi

# ================================================================
#  ★ MODIFIED: [0/8] 初始化 Conda（含自动安装）/ Init Conda (with auto-install)
# ================================================================
log_step "[0/8] 初始化 Conda / Initialize Conda"

if [ "$RESUME_MODE" = "resume" ] && [ -n "${CONDA_BASE:-}" ] && [ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]; then
    # 断点续装：从状态恢复 / Resume: restore from state
    source "$CONDA_BASE/etc/profile.d/conda.sh"
    log_skip "Conda 已就绪（断点恢复）/ Conda ready (resumed): $CONDA_BASE"
else
    # 尝试检测 conda / Try to detect conda
    CONDA_BASE=$(conda info --base 2>/dev/null || true)

    if [ -z "$CONDA_BASE" ]; then
        # 搜索常见安装路径 / Search common installation paths
        for p in "$HOME/miniconda3" "$HOME/miniconda" "$HOME/anaconda3" "/opt/conda" "/opt/miniconda3"; do
            if [ -f "$p/etc/profile.d/conda.sh" ]; then
                CONDA_BASE="$p"
                log_info "在常见路径找到 Conda / Found Conda at common path: $CONDA_BASE"
                break
            fi
        done
    fi

    if [ -n "$CONDA_BASE" ]; then
        source "$CONDA_BASE/etc/profile.d/conda.sh"
        log_info "Conda 路径 / Conda path: $CONDA_BASE"
    else
        # ★ Conda 未找到，显示交互菜单 / Conda not found, show interactive menu
        echo "" >&2
        log_warn "╔═══════════════════════════════════════════════════════════╗"
        log_warn "║  未检测到 Conda / Conda not detected                    ║"
        log_warn "║  SignalP 6.0 需要 Conda 环境来管理 Python 依赖            ║"
        log_warn "║  SignalP 6.0 requires Conda to manage Python dependencies ║"
        log_warn "╚═══════════════════════════════════════════════════════════╝"
        echo "" >&2
        echo "  [1] 自动安装 Miniconda（推荐 / Recommended）" >&2
        echo "      安装到 ~/miniconda3，无需管理员权限" >&2
        echo "      Install to ~/miniconda3, no root required" >&2
        echo "" >&2
        echo "  [2] 我自己安装，稍后回来 / I'll install it myself" >&2
        echo "" >&2
        echo "  [3] 退出 / Exit" >&2
        echo "" >&2

        while true; do
            read -p "请选择 [1-3] / Select [1-3]: " condachoice >&2
            case "$condachoice" in
                1)
                    if install_miniconda; then
                        source "$CONDA_BASE/etc/profile.d/conda.sh"
                        log_info "✅ Conda 就绪 / Conda ready: $CONDA_BASE"
                    else
                        log_error "Miniconda 安装失败，请手动安装后重试 / Miniconda install failed, please install manually"
                        exit 1
                    fi
                    break
                    ;;
                2)
                    echo "" >&2
                    echo "请手动安装 Miniconda 后重新运行本脚本 / Please install Miniconda and re-run:" >&2
                    echo "" >&2
                    echo "  # 方法 1: 下载安装 / Method 1: Download & install" >&2
                    echo "  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" >&2
                    echo "  bash Miniconda3-latest-Linux-x86_64.sh" >&2
                    echo "" >&2
                    echo "  # 方法 2: 如果已安装但不在 PATH / Method 2: If installed but not in PATH" >&2
                    echo "  export PATH=~/miniconda3/bin:\$PATH" >&2
                    echo "  然后重新运行 / Then re-run: $0" >&2
                    echo "" >&2
                    exit 0
                    ;;
                3)
                    exit 0
                    ;;
                *)
                    echo "  请输入 1-3 / Please enter 1-3" >&2
                    ;;
            esac
        done
    fi
fi

save_state "1"

# ================================================================
#  ★ MODIFIED: [1/8] 创建 Conda 环境（幂等）/ Create Conda env (idempotent)
# ================================================================
log_step "[1/8] 创建 Python 环境 / Create Python environment"

if conda env list 2>/dev/null | grep -q "^signalp6 "; then
    # 环境目录存在，但可能因中断而残缺，需验证 python 是否可用
    # Env dir exists but may be broken from interruption, verify python works
    eval "$(conda shell.bash hook 2>/dev/null)"
    if conda run -n signalp6 python --version &>/dev/null; then
        log_skip "signalp6 环境已存在且可用，跳过 / signalp6 env exists and healthy, skipping"
        log_info "（如需重建 / If rebuild needed: conda remove -n signalp6 --all -y）"
    else
        log_warn "signalp6 环境存在但 python 不可用，将删除重建 / signalp6 env broken (no python), removing..."
        conda remove -n signalp6 --all -y
        log_info "创建 signalp6 环境（python=${PYTHON_VERSION}）/ Creating signalp6 env (python=${PYTHON_VERSION})..."
        conda create -n signalp6 python="${PYTHON_VERSION}" -c conda-forge -y
    fi
else
    log_info "创建 signalp6 环境（python=${PYTHON_VERSION}）/ Creating signalp6 env (python=${PYTHON_VERSION})..."
    conda create -n signalp6 python="${PYTHON_VERSION}" -c conda-forge -y
fi

# 初始化 conda 激活函数 / Initialize conda activation function
eval "$(conda shell.bash hook 2>/dev/null)" || {
    log_error "conda shell hook 初始化失败 / conda shell hook initialization failed"
    exit 1
}
conda activate signalp6 || {
    log_error "conda activate signalp6 失败 / conda activate signalp6 failed"
    exit 1
}

PY_IMPL=$(python -c "import platform; print(platform.python_implementation())" 2>/dev/null || echo "unknown")
if [ "$PY_IMPL" != "CPython" ]; then
    log_error "Python 实现为 $PY_IMPL，需要 CPython / Python implementation is $PY_IMPL, CPython required"
    exit 1
fi
log_info "Python $(python --version 2>&1)，CPython ✅"

save_state "2"

# ================================================================
#  [2/8] 查找并解析压缩包（智能去重）/ Find and parse packages (smart dedup)
# ================================================================
log_step "[2/8] 查找压缩包（智能去重）/ Find packages (smart dedup)"

DEDUP_FILE=$(find_and_dedup_tars)
DEDUP_RC=$?
if [ $DEDUP_RC -ne 0 ] || [ ! -s "$DEDUP_FILE" ]; then
    rm -f "$DEDUP_FILE"
    log_error "未找到 signalp-*.tar.gz / signalp-*.tar.gz not found"
    echo "" >&2
    read -p "请输入压缩包完整路径 / Please enter full path to tarball: " USER_INPUT
    if [ -f "$USER_INPUT" ] && [[ "$USER_INPUT" == *.tar.gz ]]; then
        PARSED=$(parse_tar_filename "$USER_INPUT")
        MANUAL_MODE=$(echo "$PARSED" | awk '{print $1}')
        MANUAL_VER=$(echo "$PARSED" | awk '{print $2}')
        echo -e "${MANUAL_MODE}\t${MANUAL_VER}\t$(stat -c%s "$USER_INPUT" 2>/dev/null || echo 0)\t${USER_INPUT}" > "$DEDUP_FILE"
    else
        log_error "路径无效，退出 / Invalid path, exiting"
        exit 1
    fi
fi

# 显示去重后的可用包 / Show available packages after dedup
log_info "可用压缩包（同模式仅保留最高版本）/ Available packages (highest version per mode):"
AVAILABLE_MODES=()
while IFS=$'\t' read -r mode ver size path; do
    [ -z "$mode" ] && continue
    local_is_known=false
    for am in "${ALL_MODES[@]}"; do
        if [ "$mode" = "$am" ]; then local_is_known=true; break; fi
    done
    if [ "$local_is_known" = "true" ]; then
        log_info "  ✅ ${mode} (v${ver}) → $path ($(format_size $size))"
        AVAILABLE_MODES+=("$mode")
    else
        log_warn "  ? ${mode} (v${ver}) → $path [未识别模式 / unrecognized mode]"
    fi
done < "$DEDUP_FILE"

if [ ${#AVAILABLE_MODES[@]} -eq 0 ]; then
    log_error "没有找到可识别模式的压缩包 / No recognizable mode packages found"
    rm -f "$DEDUP_FILE"
    exit 1
fi

# ---- 确定要安装的模式 / Determine modes to install ----
# 断点续装时 TARGET_MODES 已从状态恢复 / On resume, TARGET_MODES restored from state
if [ ${#TARGET_MODES[@]} -gt 0 ] 2>/dev/null; then
    VALID_TARGETS=()
    for tm in "${TARGET_MODES[@]}"; do
        if grep -qP "^${tm}\t" "$DEDUP_FILE" 2>/dev/null; then
            VALID_TARGETS+=("$tm")
        else
            log_warn "模式 ${tm} 的压缩包不再可用 / Mode ${tm} package no longer available"
        fi
    done
    if [ ${#VALID_TARGETS[@]} -eq 0 ]; then
        log_warn "之前选择的模式不再可用，请重新选择 / Previously selected modes unavailable, please re-select"
        TARGET_MODES=()
    else
        TARGET_MODES=("${VALID_TARGETS[@]}")
        log_info "使用已保存的模式 / Using saved modes: ${TARGET_MODES[*]}"
    fi
fi

if [ ${#TARGET_MODES[@]} -eq 0 ]; then
    if [ -z "$SELECTED_MODE" ]; then
        # 交互选择 / Interactive selection
        CHOSEN=$(select_mode_with_packages "$DEDUP_FILE")
        if [ -z "$CHOSEN" ]; then
            log_error "无效选择，退出 / Invalid selection, exiting"
            rm -f "$DEDUP_FILE"
            exit 1
        fi
        TARGET_MODES=($CHOSEN)
    elif [ "$SELECTED_MODE" = "all" ]; then
        TARGET_MODES=("${AVAILABLE_MODES[@]}")
    else
        # 命令行指定 / CLI specified
        if [[ ! " ${ALL_MODES[*]} " =~ " ${SELECTED_MODE} " ]]; then
            log_error "无效模式 / Invalid mode: $SELECTED_MODE"
            log_error "可选值 / Valid values: ${ALL_MODES[*]}, all"
            rm -f "$DEDUP_FILE"
            exit 1
        fi
        TARGET_MODES=("$SELECTED_MODE")
    fi
fi

# 最终验证 / Final validation
VALID_TARGETS=()
for tm in "${TARGET_MODES[@]}"; do
    if grep -qP "^${tm}\t" "$DEDUP_FILE" 2>/dev/null; then
        VALID_TARGETS+=("$tm")
    else
        log_warn "模式 ${tm} 没有对应的压缩包，跳过 / Mode ${tm} has no package, skipping"
    fi
done
TARGET_MODES=("${VALID_TARGETS[@]}")

if [ ${#TARGET_MODES[@]} -eq 0 ]; then
    log_error "没有可安装的模式 / No installable modes"
    rm -f "$DEDUP_FILE"
    exit 1
fi

log_info "将安装模式 / Modes to install: ${TARGET_MODES[*]}"
save_state "3"

# ================================================================
#  ★ MODIFIED: [3/8] 按需解压（幂等）/ Extract on demand (idempotent)
# ================================================================
log_step "[3/8] 按需解压安装包 / Extract packages on demand"

declare -A EXTRACTED_PATHS  # mode → 解压后的源码目录 / extracted source dir
declare -A MODELS_DIRS      # mode → models/ 目录路径 / models/ dir path
PRIMARY_EXTRACTED=""

for mode in "${TARGET_MODES[@]}"; do
    TAR_PATH=$(grep -P "^${mode}\t" "$DEDUP_FILE" | head -n1 | cut -f4)
    [ -z "$TAR_PATH" ] && continue

    EXTRACT_BASE="$WORK_DIR/signalp_extracted_${mode}"
    # 安全守卫 / Safety guard
    if [ -z "$EXTRACT_BASE" ] || [[ "$EXTRACT_BASE" != "$WORK_DIR"* ]]; then
        log_error "解压路径异常 / Extract path abnormal: '$EXTRACT_BASE'"
        continue
    fi

    # ★ 幂等检查：如果已解压且 setup.py 存在，跳过 / Idempotent: skip if already extracted
    if [ -d "$EXTRACT_BASE" ]; then
        EXISTING_SRC=$(find "$EXTRACT_BASE" -type f -name "setup.py" -exec dirname {} \; 2>/dev/null | head -n1)
        if [ -n "$EXISTING_SRC" ] && [ -f "$EXISTING_SRC/setup.py" ]; then
            log_skip "  ${mode} 已解压，跳过 / ${mode} already extracted, skipping"
            EXTRACTED_PATHS[$mode]="$EXISTING_SRC"
            if [ -d "$EXISTING_SRC/models" ]; then
                MODELS_DIRS[$mode]="$EXISTING_SRC/models"
                log_info "  ${mode} models/ 内容 / contents:"
                ls -lh "$EXISTING_SRC/models/" 2>/dev/null | sed 's/^/    /'
            fi
            if [ -z "$PRIMARY_EXTRACTED" ]; then
                PRIMARY_EXTRACTED="$EXISTING_SRC"
                log_info "  → 用作主包进行 Python 安装 / → Used as primary package for Python install"
            fi
            echo "" >&2
            continue
        fi
    fi

    # 未解压，执行解压 / Not extracted, perform extraction
    rm -rf "$EXTRACT_BASE"
    mkdir -p "$EXTRACT_BASE"

    log_info "解压 ${mode} 包 / Extracting ${mode} package: $(basename "$TAR_PATH")"
    tar zxf "$TAR_PATH" -C "$EXTRACT_BASE"

    # 查找源码目录 / Find source directory
    SRC=$(find "$EXTRACT_BASE" -type f -name "setup.py" -exec dirname {} \; 2>/dev/null | head -n1)
    if [ -z "$SRC" ]; then
        log_error "解压后未找到 setup.py / setup.py not found after extraction: $(basename "$TAR_PATH")"
        continue
    fi

    EXTRACTED_PATHS[$mode]="$SRC"

    # 记录 models/ 目录 / Record models/ directory
    if [ -d "$SRC/models" ]; then
        MODELS_DIRS[$mode]="$SRC/models"
        log_info "  ${mode} models/ 内容 / contents:"
        ls -lh "$SRC/models/" 2>/dev/null | sed 's/^/    /'
    fi

    # 第一个模式作为主包 / First mode used for setup.py install
    if [ -z "$PRIMARY_EXTRACTED" ]; then
        PRIMARY_EXTRACTED="$SRC"
        log_info "  → 用作主包进行 Python 安装 / → Used as primary package for Python install"
    fi
    echo "" >&2
done

rm -f "$DEDUP_FILE"

if [ -z "$PRIMARY_EXTRACTED" ]; then
    log_error "所有包解压失败 / All packages failed to extract"
    exit 1
fi

save_state "4"

# ================================================================
#  ★ MODIFIED: [4/8] 编译安装（幂等）/ Build and install (idempotent)
# ================================================================
log_step "[4/8] 编译安装 / Build and install"

# ★ 幂等检查：如果 signalp 包已安装，跳过 / Idempotent: skip if signalp package installed
# 动态查找 .egg 目录，不硬编码版本号 / Dynamically find .egg dir, no hardcoded version
SITE_PKGS_CHECK=$(python -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "")
SIGNALP6_EGG_DIR=$(find "${SITE_PKGS_CHECK:-/dev/null}" -maxdepth 1 -type d -name "signalp6*.egg" 2>/dev/null | head -n1)
if [ -n "$SIGNALP6_EGG_DIR" ] && [ -d "$SIGNALP6_EGG_DIR/signalp" ]; then
    log_skip "signalp 包已安装，跳过编译 / signalp package already installed, skipping build"
elif pip show signalp6 > /dev/null 2>&1; then
    log_skip "signalp 包已安装，跳过编译 / signalp package already installed, skipping build"
else
    cd "$PRIMARY_EXTRACTED"
    log_info "执行 python setup.py install（限时 300 秒）/ Running python setup.py install (300s timeout)..."
    log_warn "注：安装完成后可能卡住不退出，脚本会自动处理 / Note: may hang after install, script handles it"

    set +e
    timeout 300 python setup.py install 2>&1 | tee /tmp/signalp_install.log
    INSTALL_RC=${PIPESTATUS[0]}
    # Restore original state: script runs with set -uo pipefail (NO -e)
    set +e

    if [ $INSTALL_RC -eq 124 ]; then
        log_warn "安装超时 300 秒被终止（正常现象，安装已完成）/ Install timed out at 300s (normal, install complete)"
    elif [ $INSTALL_RC -ne 0 ]; then
        log_warn "setup.py 退出码 $INSTALL_RC（可能是正常卡住被终止）/ setup.py exit code $INSTALL_RC (may be normal hang)"
    else
        log_info "setup.py install 正常完成 ✅ / setup.py install completed normally ✅"
    fi

    # 验证安装 / Verify install
    SIGNALP6_EGG_DIR=$(find "${SITE_PKGS_CHECK:-/dev/null}" -maxdepth 1 -type d -name "signalp6*.egg" 2>/dev/null | head -n1)
    if [ -n "$SIGNALP6_EGG_DIR" ] && [ -d "$SIGNALP6_EGG_DIR/signalp" ] || \
       pip show signalp6 > /dev/null 2>&1; then
        log_info "✅ signalp 包已安装 / signalp package installed"
    else
        log_warn "无法确认安装结果，继续尝试... / Cannot confirm install result, continuing..."
    fi
    cd "$WORK_DIR"
fi

save_state "5a"

# ================================================================
#  ★ MODIFIED: [5/8] 安装所有依赖（每个子步骤幂等）/ Install dependencies (each substep idempotent)
# ================================================================
log_step "[5/8] 安装所有依赖 / Install all dependencies"

echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "【重要】必须在 import signalp 之前装完所有依赖！/ [Important] Install ALL dependencies before import signalp!" >&2
echo "  signalp 内部导入链 / import chain: signalp → predict → torch" >&2
echo "                            → make_sequence_plot → matplotlib → PIL" >&2
echo "  缺任何一个都会 ImportError / Missing any causes ImportError" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2

# 5a. 修复 Pillow（libtiff.so.5 问题）/ Fix Pillow (libtiff.so.5 issue)
log_info "[5a] 修复 Pillow（解决 libtiff.so.5）/ Fixing Pillow (libtiff.so.5)..."
if python -c "from PIL import Image" 2>/dev/null; then
    log_skip "  Pillow 已就绪 / Pillow already installed"
else
    pip uninstall -y Pillow pillow 2>/dev/null || true
    conda install -c conda-forge pillow -y 2>/dev/null || true
    if ! python -c "from PIL import Image" 2>/dev/null; then
        log_warn "  conda 安装 Pillow 失败，尝试 pip / conda Pillow failed, trying pip"
        pip install "pillow${PILLOW_CONSTRAINT}" 2>/dev/null || true
    fi
    python -c "from PIL import Image; print('  Pillow ✅')" 2>/dev/null || log_warn "Pillow 验证失败 / Pillow verification failed"
fi
save_state "5b"

# 5b. matplotlib
log_info "[5b] 安装 matplotlib..."
if python -c "import matplotlib" 2>/dev/null; then
    log_skip "  matplotlib 已就绪 / matplotlib already installed"
else
    MATPLOTLIB_INSTALLED=false
    pip install "matplotlib${MATPLOTLIB_CONSTRAINT}" 2>/dev/null && MATPLOTLIB_INSTALLED=true || true
    if [ "$MATPLOTLIB_INSTALLED" = "false" ]; then
        log_warn "  pip 安装 matplotlib 失败，尝试 conda / pip matplotlib failed, trying conda..."
        conda install -c conda-forge matplotlib -y 2>/dev/null || true
    fi
    python -c "import matplotlib; print('  Matplotlib ✅')" 2>/dev/null || log_warn "matplotlib 验证失败 / matplotlib verification failed"
fi
save_state "5c"

# 5c. NumPy（必须 <2.0）/ NumPy (must be <2.0 for older Python)
log_info "[5c] 安装 NumPy / Installing NumPy..."
if python -c "import numpy" 2>/dev/null; then
    log_skip "  NumPy 已就绪 / NumPy already installed"
else
    pip install "numpy${NUMPY_CONSTRAINT}" || true
    python -c "import numpy; print(f'  NumPy {numpy.__version__} ✅')" 2>/dev/null || log_warn "NumPy 验证失败 / NumPy verification failed"
fi
save_state "5d"

# 5d. PyTorch / PyTorch
log_info "[5d] 安装 PyTorch ${PYTORCH_VERSION} ${TORCH_VARIANT} 版 / Installing PyTorch ${PYTORCH_VERSION} ${TORCH_VARIANT}..."
if python -c "import torch" 2>/dev/null; then
    log_skip "  PyTorch 已就绪 / PyTorch already installed"
else
    PYTORCH_INSTALLED=false

    log_info "  尝试 pip 安装 torch ${PYTORCH_VERSION}+${TORCH_VARIANT}... / Trying pip install torch ${PYTORCH_VERSION}+${TORCH_VARIANT}..."
    pip install torch==${PYTORCH_VERSION}+${TORCH_VARIANT} torchvision==${TORCHVISION_VERSION}+${TORCH_VARIANT} \
        -f https://download.pytorch.org/whl/torch_stable.html 2>/dev/null
    if python -c "import torch; print(f'  PyTorch {torch.__version__} ✅')" 2>/dev/null; then
        log_info "  pip 安装成功，跳过 conda 安装 / pip install succeeded, skipping conda"
        PYTORCH_INSTALLED=true
    else
        log_warn "  pip 安装失败，尝试 conda 安装... / pip failed, trying conda..."
        conda install -c pytorch pytorch==${PYTORCH_VERSION} ${TORCH_VARIANT}only -y || true
        if python -c "import torch; print(f'  PyTorch {torch.__version__} ✅')" 2>/dev/null; then
            PYTORCH_INSTALLED=true
        fi
    fi

    if [ "$PYTORCH_INSTALLED" = "false" ]; then
        log_error "PyTorch 安装失败 / PyTorch installation failed，请手动安装 / please install manually"
        echo "  参考命令 / Reference command:" >&2
        echo "    pip install torch==${PYTORCH_VERSION}+${TORCH_VARIANT} torchvision==${TORCHVISION_VERSION}+${TORCH_VARIANT} -f https://download.pytorch.org/whl/torch_stable.html" >&2
    fi
fi
save_state "5e"

# 5e. tqdm（兼容旧 Python）/ tqdm (compat with older Python)
log_info "[5e] 安装 tqdm / Installing tqdm..."
if python -c "import tqdm" 2>/dev/null; then
    log_skip "  tqdm 已就绪 / tqdm already installed"
else
    pip install "tqdm${TQDM_CONSTRAINT}" || true
    python -c "import tqdm; print('  tqdm ✅')" 2>/dev/null || log_warn "tqdm 验证失败 / tqdm verification failed"
fi
save_state "5f"

# 5f. 最终验证 / Final verification
log_info "[5f] 验证 import signalp... / Verifying import signalp..."
if python -c "import signalp; print('  signalp import ✅')" 2>/dev/null; then
    log_info "✅ 所有依赖安装完成，signalp 可正常导入 / All dependencies installed, signalp importable"
else
    log_error "import signalp 仍然失败 / import signalp still failing，详细错误 / detailed errors:"
    python -c "import signalp" 2>&1 | tail -10
    echo "" >&2
    log_warn "逐个检查依赖状态 / Checking dependencies one by one:" >&2
    python -c "import torch; print('  torch ✅')"      2>/dev/null || log_error "  torch ❌ → pip install torch==${PYTORCH_VERSION}+${TORCH_VARIANT} -f https://download.pytorch.org/whl/torch_stable.html"
    python -c "from PIL import Image; print('  PIL ✅')" 2>/dev/null || log_error "  Pillow ❌ → conda install -c conda-forge pillow -y"
    python -c "import matplotlib; print('  matplotlib ✅')" 2>/dev/null || log_error "  matplotlib ❌ → pip install 'matplotlib${MATPLOTLIB_CONSTRAINT}'"
    python -c "import tqdm; print('  tqdm ✅')"        2>/dev/null || log_error "  tqdm ❌ → pip install 'tqdm${TQDM_CONSTRAINT}'"
    echo "" >&2
    log_error "请根据以上提示手动安装缺失包后重试 / Please install missing packages manually and retry"
    log_info "💡 提示：你可以直接重新运行此脚本，已完成的步骤会自动跳过 / Tip: re-run this script, completed steps will be skipped automatically"
    exit 1
fi

save_state "6"

# ================================================================
#  ★ MODIFIED: [6/8] 部署模型权重（幂等）/ Deploy model weights (idempotent)
# ================================================================
log_step "[6/8] 部署模型权重 / Deploy model weights"

SIGNALP_DIR=$(python -c "import signalp; import os; print(os.path.dirname(signalp.__file__))" 2>/dev/null)

if [ -z "$SIGNALP_DIR" ]; then
    log_error "无法获取 SignalP 安装路径 / Cannot get SignalP install path"
    exit 1
fi

log_info "SignalP 安装路径 / SignalP install path: $SIGNALP_DIR"

MW_DIR="$SIGNALP_DIR/model_weights"
mkdir -p "$MW_DIR"

MW_FILE_COUNT=$(find "$MW_DIR" -type f -not -name "README.md" 2>/dev/null | wc -l)
if [ "$MW_FILE_COUNT" -gt 0 ]; then
    log_info "model_weights/ 已有 ${MW_FILE_COUNT} 个文件 / model_weights/ already has ${MW_FILE_COUNT} files"
else
    log_info "model_weights/ 当前为空壳（仅有 README.md）/ model_weights/ is empty (README.md only)"
fi

DEPLOYED_MODES=()
FAILED_MODES=()

# ★ 动态发现模型文件名 / Dynamic model file discovery
# 如果 models/ 目录中的文件名和 MODEL_FILE_MAP 不匹配，自动更新映射
# If filenames in models/ don't match MODEL_FILE_MAP, auto-update the mapping
for mode in "${TARGET_MODES[@]}"; do
    models_dir="${MODELS_DIRS[$mode]:-}"
    if [ -z "$models_dir" ] || [ ! -d "$models_dir" ]; then
        continue
    fi
    expected="${MODEL_FILE_MAP[$mode]}"
    if [ -e "$models_dir/$expected" ]; then
        continue  # 预期文件存在，无需调整 / Expected file exists, no adjustment needed
    fi
    # 预期文件不存在，尝试从 models/ 目录自动发现 / Expected not found, try auto-discovery
    if [ "$mode" = "fast" ]; then
        # fast: 寻找 .pt 文件（排除 README） / fast: look for .pt file (exclude README)
        FOUND_PT=$(find "$models_dir" -maxdepth 1 -name "*.pt" -not -name "README*" -print -quit 2>/dev/null)
        if [ -n "$FOUND_PT" ]; then
            MODEL_FILE_MAP[$mode]="$(basename "$FOUND_PT")"
            log_warn "  ⚡ 动态发现 fast 模型: $(basename "$FOUND_PT")（替代 / replacing $expected）"
        fi
    elif [ "$mode" = "slow-sequential" ]; then
        # slow-sequential: 寻找包含 sequential 的目录 / slow-sequential: find dir with "sequential" in name
        FOUND_DIR=$(find "$models_dir" -maxdepth 1 -type d -name "*sequential*" -print -quit 2>/dev/null)
        if [ -n "$FOUND_DIR" ]; then
            MODEL_FILE_MAP[$mode]="$(basename "$FOUND_DIR")"
            log_warn "  ⚡ 动态发现 slow-sequential 模型: $(basename "$FOUND_DIR")（替代 / replacing $expected）"
        fi
    fi
done

for mode in "${TARGET_MODES[@]}"; do
    model_target="${MODEL_FILE_MAP[$mode]}"
    models_dir="${MODELS_DIRS[$mode]:-}"

    log_info "──────────────────────────────"
    log_info "部署 ${mode} 模型 / Deploying ${mode} model: ${model_target}"

    # ★ 幂等检查：模型已部署且与源一致则跳过 / Idempotent: skip if deployed AND matches source
    if [ -d "$MW_DIR/$model_target" ] || [ -f "$MW_DIR/$model_target" ]; then
        # 验证完整性：对比源和目标的文件数/大小，避免中断后残留损坏文件
        # Verify integrity: compare file count/size to detect interrupted copies
        SKIP_DEPLOY=true
        if [ -n "$models_dir" ] && [ -d "$models_dir" ]; then
            if [ -f "$models_dir/$model_target" ] || [ -d "$models_dir/$model_target" ]; then
                SRC_SIZE=$(du -sb "$models_dir/$model_target" 2>/dev/null | cut -f1)
                DST_SIZE=$(du -sb "$MW_DIR/$model_target" 2>/dev/null | cut -f1)
                SRC_FC=$(find "$models_dir/$model_target" -type f 2>/dev/null | wc -l)
                DST_FC=$(find "$MW_DIR/$model_target" -type f 2>/dev/null | wc -l)
                if [ "$SRC_SIZE" = "$DST_SIZE" ] && [ "$SRC_FC" = "$DST_FC" ]; then
                    log_skip "  ${mode} 模型已部署且完整（${DST_FC} 文件 / files, $(format_size $DST_SIZE)），跳过 / already deployed, skipping"
                else
                    log_warn "  ${mode} 模型文件不完整（源 / src: ${SRC_FC} 文件 / files $(format_size $SRC_SIZE), 目标 / dst: ${DST_FC} 文件 / files $(format_size $DST_SIZE)），将重新复制 / incomplete, re-copying"
                    rm -rf "$MW_DIR/$model_target"
                    SKIP_DEPLOY=false
                fi
            fi
        else
            # 源目录不可用，仅检查目标存在 / Source not available, only check destination exists
            if [ -d "$MW_DIR/$model_target" ]; then
                FC=$(find "$MW_DIR/$model_target" -type f | wc -l)
                TS=$(du -sb "$MW_DIR/$model_target" 2>/dev/null | cut -f1)
                log_skip "  ${mode} 模型已部署（${FC} 文件 / files, $(format_size $TS)），跳过 / already deployed, skipping"
            else
                FS=$(stat -c%s "$MW_DIR/$model_target" 2>/dev/null || stat -f%z "$MW_DIR/$model_target" 2>/dev/null || echo 0)
                log_skip "  ${mode} 模型已部署（$(format_size $FS)），跳过 / already deployed, skipping"
            fi
        fi
        if [ "$SKIP_DEPLOY" = "true" ]; then
            DEPLOYED_MODES+=("$mode")
            echo "" >&2
            continue
        fi
    fi

    MODEL_SRC=""

    # 优先从本模式解压目录精确匹配 / First: exact match from this mode's extract dir
    if [ -n "$models_dir" ] && [ -d "$models_dir" ]; then
        if [ -f "$models_dir/$model_target" ]; then
            MODEL_SRC="$models_dir/$model_target"
            log_info "  ✓ 精确匹配（文件）/ Exact match (file): $MODEL_SRC"
        elif [ -d "$models_dir/$model_target" ]; then
            MODEL_SRC="$models_dir/$model_target"
            log_info "  ✓ 精确匹配（目录）/ Exact match (dir): $MODEL_SRC"
        fi
    fi

    # 如果本模式目录没找到，搜索其他模式的解压目录 / If not found, search other mode dirs
    if [ -z "$MODEL_SRC" ]; then
        for other_mode in "${!MODELS_DIRS[@]}"; do
            [ "$other_mode" = "$mode" ] && continue
            omd="${MODELS_DIRS[$other_mode]}"
            [ -z "$omd" ] || [ ! -d "$omd" ] && continue
            if [ -f "$omd/$model_target" ]; then
                MODEL_SRC="$omd/$model_target"
                log_info "  ✓ 从 ${other_mode} 包找到 / Found in ${other_mode} package: $MODEL_SRC"
                break
            elif [ -d "$omd/$model_target" ]; then
                MODEL_SRC="$omd/$model_target"
                log_info "  ✓ 从 ${other_mode} 包找到 / Found in ${other_mode} package: $MODEL_SRC"
                break
            fi
        done
    fi

    # 全盘搜索兜底 / Full disk search fallback
    if [ -z "$MODEL_SRC" ]; then
        log_warn "  在已解压目录中未找到，启动全盘搜索... / Not found in extracted dirs, starting full search..."
        if [ "$mode" = "slow-sequential" ]; then
            MODEL_SRC=$(timeout 30 find /home -maxdepth 6 -type d \
                -name "*sequential*model*" -path "*signalp*" \
                -print -quit 2>/dev/null || true)
        else
            MODEL_SRC=$(timeout 30 find /home -maxdepth 6 -type f \
                -name "*distilled*signalp*.pt" \
                -print -quit 2>/dev/null || true)
        fi
        if [ -n "$MODEL_SRC" ]; then
            log_info "  ✓ 全盘搜索找到 / Found by full search: $MODEL_SRC"
        fi
    fi

    # 执行复制 / Execute copy
    if [ -n "$MODEL_SRC" ]; then
        if [ -d "$MODEL_SRC" ]; then
            cp -r "$MODEL_SRC" "$MW_DIR/"
            if [ -d "$MW_DIR/$model_target" ]; then
                FILE_COUNT=$(find "$MW_DIR/$model_target" -type f | wc -l)
                TOTAL_SIZE=$(du -sb "$MW_DIR/$model_target" 2>/dev/null | cut -f1)
                log_info "  ✅ ${mode} 模型复制完成 / Model copy complete: ${FILE_COUNT} 个文件 / files, $(format_size $TOTAL_SIZE)"
                DEPLOYED_MODES+=("$mode")
            else
                log_error "  ❌ ${mode} 模型复制失败 / Model copy failed"
                FAILED_MODES+=("$mode")
            fi
        elif [ -f "$MODEL_SRC" ]; then
            cp "$MODEL_SRC" "$MW_DIR/"
            if [ -f "$MW_DIR/$model_target" ]; then
                NEW_SIZE=$(stat -c%s "$MW_DIR/$model_target" 2>/dev/null || stat -f%z "$MW_DIR/$model_target" 2>/dev/null || echo 0)
                log_info "  ✅ ${mode} 模型复制完成 / Model copy complete: $(format_size $NEW_SIZE)"
                DEPLOYED_MODES+=("$mode")
            else
                log_error "  ❌ ${mode} 模型复制失败 / Model copy failed"
                FAILED_MODES+=("$mode")
            fi
        fi
    else
        log_error "  ❌ 未找到 ${mode} 模型 / Model not found: ${model_target}"
        FAILED_MODES+=("$mode")
        echo "" >&2
        read -p "    请输入 ${model_target} 的完整路径（或回车跳过）/ Please enter full path to ${model_target} (or Enter to skip): " USER_MODEL
        if [ -n "$USER_MODEL" ] && ([ -d "$USER_MODEL" ] || [ -f "$USER_MODEL" ]); then
            cp -r "$USER_MODEL" "$MW_DIR/"
            if [ -e "$MW_DIR/$model_target" ]; then
                log_info "  ✅ ${mode} 手动指定模型复制完成 / Manual model copy complete"
                DEPLOYED_MODES+=("$mode")
                FAILED_MODES=("${FAILED_MODES[@]/$mode}")
            fi
        else
            log_warn "  跳过 ${mode} 模型复制 / Skipping ${mode} model copy"
        fi
    fi
    echo "" >&2
done

# 模型部署汇总 / Model deployment summary
log_info "╔══════════════════════════════════════════════════════╗"
log_info "║         模型部署汇总 / Model Deployment Summary         ║"
log_info "╠══════════════════════════════════════════════════════╣"
if [ ${#DEPLOYED_MODES[@]} -gt 0 ]; then
    for dm in "${DEPLOYED_MODES[@]}"; do
        mt="${MODEL_FILE_MAP[$dm]}"
        if [ -d "$MW_DIR/$mt" ]; then
            fc=$(find "$MW_DIR/$mt" -type f | wc -l)
            ts=$(du -sb "$MW_DIR/$mt" 2>/dev/null | cut -f1)
            log_info "║  ✅ ${dm}: ${mt}/ (${fc} 文件 / files, $(format_size $ts))  ║"
        elif [ -f "$MW_DIR/$mt" ]; then
            fs=$(stat -c%s "$MW_DIR/$mt" 2>/dev/null || stat -f%z "$MW_DIR/$mt" 2>/dev/null || echo 0)
            log_info "║  ✅ ${dm}: ${mt} ($(format_size $fs))  ║"
        fi
    done
fi
if [ ${#FAILED_MODES[@]} -gt 0 ]; then
    for fm in "${FAILED_MODES[@]}"; do
        log_error "║  ❌ ${fm}: ${MODEL_FILE_MAP[$fm]} (缺失 / missing)  ║"
    done
    log_warn "║  缺失模式将不可用，可稍后手动补充 / Missing modes unavailable, add manually later"
fi
log_info "╚══════════════════════════════════════════════════════╝"

save_state "7"

# ---- [7/8] 环境诊断 / Environment diagnostics ----
log_step "[7/8] 环境诊断 / Environment diagnostics"

cat > "$WORK_DIR/check_signalp_env.sh" << 'DIAG_SCRIPT'
#!/bin/bash
echo "╔════════════════════════════════════════════════════════╗"
echo "║           SignalP 环境诊断报告 (v15)                    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "1. Python 环境 / Python environment:"
python --version 2>&1
python -c "import platform; print('   实现 / Implementation:', platform.python_implementation())" 2>/dev/null
echo ""
echo "2. 核心依赖 / Core dependencies:"
python -c "import numpy; print('   NumPy:      ', numpy.__version__)"    2>/dev/null || echo "   ❌ NumPy"
python -c "import torch; print('   PyTorch:    ', torch.__version__)"    2>/dev/null || echo "   ❌ PyTorch"
python -c "import PIL; print('   Pillow:     ', PIL.__version__)"       2>/dev/null || echo "   ❌ Pillow"
python -c "import matplotlib; print('   Matplotlib: ', matplotlib.__version__)" 2>/dev/null || echo "   ❌ Matplotlib"
python -c "import tqdm; print('   tqdm:       OK')"                    2>/dev/null || echo "   ❌ tqdm"
echo ""
echo "3. SignalP 状态 / SignalP status:"
SIGNALP_PATH=$(python -c "import signalp; print(signalp.__file__)" 2>/dev/null || true)
if [ -n "$SIGNALP_PATH" ]; then
    echo "   ✅ import signalp 成功 / success: $SIGNALP_PATH"
    SIGNALP_DIR=$(dirname "$SIGNALP_PATH")
    MW_DIR="$SIGNALP_DIR/model_weights"
    echo ""
    echo "4. 模型权重状态（model_weights/）/ Model weights status:"
    if [ -d "$MW_DIR" ]; then
        echo "   目录 / Dir: $MW_DIR"
        echo ""
        # 动态列出 model_weights 内容，不硬编码文件名
        # Dynamically list model_weights contents, no hardcoded filenames
        for item in "$MW_DIR"/*; do
            [ -e "$item" ] || continue
            name=$(basename "$item")
            if [ "$name" = "README.md" ]; then
                continue
            fi
            if [ -d "$item" ]; then
                FILE_COUNT=$(find "$item" -type f | wc -l)
                TOTAL_SIZE=$(du -sh "$item" 2>/dev/null | cut -f1)
                echo "   ✅ ${name}/ - ${FILE_COUNT} 文件 / files, ${TOTAL_SIZE}"
            elif [ -f "$item" ]; then
                SIZE=$(du -sh "$item" 2>/dev/null | cut -f1)
                echo "   ✅ ${name} - ${SIZE}"
            fi
        done
        # 检查是否为空 / Check if empty
        NON_README=$(find "$MW_DIR" -maxdepth 1 -not -name "README.md" -not -name "model_weights" -not -name "." -print -quit 2>/dev/null)
        if [ -z "$NON_README" ]; then
            echo "   ⚠️  空壳目录（仅有 README.md）/ Empty dir (README.md only)"
        fi
    else
        echo "   ❌ model_weights 目录缺失 / model_weights dir missing"
    fi
else
    echo "   ❌ import signalp 失败 / failed"
fi
echo ""
echo "5. signalp6 命令 / signalp6 command:"
which signalp6 2>/dev/null && echo "   ✅ signalp6 在 PATH / in PATH" || echo "   ❌ signalp6 不在 PATH / not in PATH"
echo ""
echo "════════════════════ 诊断结束 / Diagnostics complete ═══════════════"
DIAG_SCRIPT

chmod +x "$WORK_DIR/check_signalp_env.sh"
bash "$WORK_DIR/check_signalp_env.sh"

save_state "8"

# ---- [8/8] 最终验证 / Final verification ----
log_step "[8/8] 最终验证 / Final verification"

if conda run -n signalp6 signalp6 --help > /dev/null 2>&1; then
    echo "" >&2
    echo "🎉🎉🎉 安装成功！SignalP 已就绪 🎉🎉🎉" >&2
    echo "🎉🎉🎉 Installation successful! SignalP is ready 🎉🎉🎉" >&2
    echo "" >&2
    echo "已安装模式 / Installed modes:" >&2
    for dm in "${DEPLOYED_MODES[@]}"; do
        echo "  ✅ ${dm} - ${MODE_DESC[$dm]}" >&2
    done
    if [ ${#FAILED_MODES[@]} -gt 0 ]; then
        echo "" >&2
        echo "缺失模式（需手动补充模型权重到 / Missing modes, need to manually add model weights to $MW_DIR/）:" >&2
        for fm in "${FAILED_MODES[@]}"; do
            echo "  ❌ ${fm} → 需要 / need: ${MODEL_FILE_MAP[$fm]}" >&2
        done
    fi
    echo "" >&2
    echo "使用方法 / Usage:" >&2
    echo "  conda activate signalp6" >&2
    if [ ${#DEPLOYED_MODES[@]} -eq 1 ]; then
        echo "  signalp6 -i input.fasta -o results -m ${DEPLOYED_MODES[0]}" >&2
    else
        echo "  signalp6 -i input.fasta -o results -m <$(IFS='|'; echo "${DEPLOYED_MODES[*]}")>" >&2
    fi
    echo "" >&2
    echo "故障排查 / Troubleshooting:" >&2
    echo "  conda activate signalp6 && bash $WORK_DIR/check_signalp_env.sh" >&2

    # ★ 安装成功，清除状态文件 / Success: clear state file
    clear_state
else
    echo "" >&2
    echo "❌ signalp6 --help 验证失败 / verification failed" >&2
    echo "" >&2
    echo "请手动排查 / Please troubleshoot manually:" >&2
    echo "  conda activate signalp6" >&2
    echo "  python -c \"import signalp; print('OK')\"" >&2
    echo "  signalp6 --help" >&2
    echo "" >&2
    echo "💡 或者直接重新运行此脚本，已完成的步骤会自动跳过" >&2
    echo "   Or simply re-run this script, completed steps will be skipped automatically" >&2
    echo "   $0" >&2
fi
