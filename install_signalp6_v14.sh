#!/bin/bash
# ============================================================
# SignalP 6.0 全自动安装脚本（v14 双语发布版）
# SignalP 6.0 Fully Automated Installer (v14 Bilingual Release)
# ============================================================
#
# 支持模式 / Supported modes:
#   fast            快速模式 - 蒸馏模型，速度最快
#   slow-sequential 慢速顺序模式 - 最高精度，逐条处理
#
# 用法 / Usage:
#   ./install_signalp6_v14.sh                    # 交互选择 / Interactive mode selection
#   ./install_signalp6_v14.sh -m fast            # 指定 fast 模式 / Specify fast mode
#   ./install_signalp6_v14.sh -m slow-sequential # 指定 slow-sequential
#   ./install_signalp6_v14.sh -m all            # 安装所有可用模式 / Install all available modes
#   ./install_signalp6_v14.sh -h                 # 查看帮助 / Show help
#
# v14 改进 (based on v13 real-machine validation):
#   - 双语输出（中文 + English in parentheses）
#   - 所有 v13 修复：智能去重、按需解压、交互菜单、rm -rf 安全守卫
#   - 修复 parse_tar_filename 版本解析（右到左分割）
#   - 修复 stdout/stderr 混合问题（所有 log 输出到 >&2）
#   - 修复 TARGET_MODES 重复问题
#
# ============================================================

set -uo pipefail

WORK_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)"

# ---- 模式配置 / Mode configuration ----
declare -A MODEL_FILE_MAP=(
    ["fast"]="distilled_model_signalp6.pt"
    ["slow-sequential"]="sequential_models_signalp6"
)

declare -A MODE_DESC=(
    ["fast"]="快速模式 - 蒸馏模型，速度最快 / Fast mode - distilled model, fastest speed"
    ["slow-sequential"]="慢速顺序模式 - 最高精度，逐条处理 / Slow-sequential - highest accuracy, sequential processing"
)

ALL_MODES=("fast" "slow-sequential")

# ---- 工具函数 / Utility functions ----

# 所有日志输出到 stderr，避免被 $(...) 捕获
# All log output goes to stderr to avoid capture by $(...)
log_info()  { echo -e "\033[1;32m[INFO]\033[0m  $1" >&2; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $1" >&2; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; }
log_step()  { echo "" >&2; echo "===== $1 =====" >&2; }

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
# 输入: signalp-6.0h.fast.tar.gz
# 输出: mode version
parse_tar_filename() {
    local filename
    filename=$(basename "$1")
    local base="${filename%.tar.gz}"
    local rest="${base#signalp-}"
    # 版本号可能含点（如 6.0h），从右边分割
    # Version may contain dots (e.g. 6.0h), split from right
    local mode_part="${rest##*.}"
    local ver="${rest%.*}"

    local mode=""
    case "$mode_part" in
        fast)
            mode="fast"
            ;;
        slow_sequential|slow-sequential|slowsequential)
            mode="slow-sequential"
            ;;
        *)
            mode="$mode_part"
            ;;
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
        done < <(find "$d" -maxdepth 3 -name "signalp-6*.tar.gz" -print0 2>/dev/null)
    done

    # 全盘搜索（限时 30 秒）/ Full disk search (30s timeout)
    while IFS= read -r -d '' f; do
        all_tars+=("$f")
    done < <(timeout 30 find /home -maxdepth 5 -name "signalp-6*.tar.gz" -print0 2>/dev/null || true)

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

    # 输入验证循环 / Input validation loop
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

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            SELECTED_MODE="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法 / Usage: $0 [-m MODE] [-h]"
            echo ""
            echo "可用模式（取决于找到的压缩包 / Available modes depend on found packages）:"
            for m in "${ALL_MODES[@]}"; do
                echo "  ${m}  - ${MODE_DESC[$m]}"
            done
            echo "  all    - 安装所有可用模式的模型权重 / Install all available model weights"
            echo ""
            echo "示例 / Examples:"
            echo "  $0                     # 交互选择 / Interactive selection"
            echo "  $0 -m fast             # 安装 fast 模式 / Install fast mode"
            echo "  $0 -m slow-sequential # 安装 slow-sequential / Install slow-sequential"
            echo "  $0 -m all              # 安装所有可用模式 / Install all available"
            exit 0
            ;;
        *)
            log_error "未知参数 / Unknown option: $1 (使用 -h 查看帮助 / Use -h for help)"
            exit 1
            ;;
    esac
done

# ---- [0/8] 初始化 Conda / Initialize Conda ----
log_step "[0/8] 初始化 Conda / Initialize Conda"
CONDA_BASE=$(conda info --base 2>/dev/null || true)
if [ -z "$CONDA_BASE" ]; then
    log_error "未检测到 conda / Conda not detected，请先安装 Anaconda/Miniconda"
    log_error "Please install Anaconda/Miniconda first"
    exit 1
fi
source "$CONDA_BASE/etc/profile.d/conda.sh"
log_info "Conda 路径 / Conda path: $CONDA_BASE"

# ---- [1/8] 创建 Conda 环境 / Create Conda environment ----
log_step "[1/8] 创建 Python 环境 / Create Python environment"

if conda env list 2>/dev/null | grep -q "^signalp6 "; then
    log_warn "signalp6 环境已存在，跳过创建 / signalp6 env already exists, skipping creation"
    log_info "（如需重建 / If rebuild needed: conda remove -n signalp6 --all -y）"
else
    log_info "创建 signalp6 环境（python=3.7）/ Creating signalp6 env (python=3.7)..."
    conda create -n signalp6 python=3.7 -c conda-forge -y
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

# ---- [2/8] 查找并解析压缩包（智能去重）/ Find and parse packages (smart dedup) ----
log_step "[2/8] 查找压缩包（智能去重）/ Find packages (smart dedup)"

DEDUP_FILE=$(find_and_dedup_tars)
DEDUP_RC=$?
if [ $DEDUP_RC -ne 0 ] || [ ! -s "$DEDUP_FILE" ]; then
    rm -f "$DEDUP_FILE"
    log_error "未找到 signalp-6*.tar.gz / signalp-6*.tar.gz not found"
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

# 验证选择的模式是否有对应的包 / Verify selected modes have packages
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

# ---- [3/8] 按需解压 / Extract on demand ----
log_step "[3/8] 按需解压安装包 / Extract packages on demand"

declare -A EXTRACTED_PATHS  # mode → 解压后的源码目录 / extracted source dir
declare -A MODELS_DIRS      # mode → models/ 目录路径 / models/ dir path
PRIMARY_EXTRACTED=""

for mode in "${TARGET_MODES[@]}"; do
    TAR_PATH=$(grep -P "^${mode}\t" "$DEDUP_FILE" | head -n1 | cut -f4)
    [ -z "$TAR_PATH" ] && continue

    # 解压目录使用模式名 / Extract dir named by mode
    EXTRACT_BASE="$WORK_DIR/signalp_extracted_${mode}"
    # 安全守卫：防止变量为空导致 rm -rf 误删 / Safety guard against empty var
    if [ -z "$EXTRACT_BASE" ] || [[ "$EXTRACT_BASE" != "$WORK_DIR"* ]]; then
        log_error "解压路径异常 / Extract path abnormal: '$EXTRACT_BASE'，跳过以防止误删 / skipping to prevent accidental deletion"
        continue
    fi
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

    # 第一个模式作为主包（用于 setup.py install）/ First mode used for setup.py install
    if [ -z "$PRIMARY_EXTRACTED" ]; then
        PRIMARY_EXTRACTED="$SRC"
        log_info "  → 用作主包进行 Python 安装 / → Used as primary package for Python install"
    fi
    echo ""
done

rm -f "$DEDUP_FILE"

if [ -z "$PRIMARY_EXTRACTED" ]; then
    log_error "所有包解压失败 / All packages failed to extract"
    exit 1
fi

# ---- [4/8] 编译安装 / Build and install ----
log_step "[4/8] 编译安装 / Build and install"

cd "$PRIMARY_EXTRACTED"
log_info "执行 python setup.py install（限时 300 秒）/ Running python setup.py install (300s timeout)..."
log_warn "注：安装完成后可能卡住不退出，脚本会自动处理 / Note: may hang after install, script handles it"

set +e
timeout 300 python setup.py install 2>&1 | tee /tmp/signalp_install.log
INSTALL_RC=${PIPESTATUS[0]}
set -e

if [ $INSTALL_RC -eq 124 ]; then
    log_warn "安装超时 300 秒被终止（正常现象，安装已完成）/ Install timed out at 300s (normal, install complete)"
elif [ $INSTALL_RC -ne 0 ]; then
    log_warn "setup.py 退出码 $INSTALL_RC（可能是正常卡住被终止）/ setup.py exit code $INSTALL_RC (may be normal hang)"
else
    log_info "setup.py install 正常完成 ✅ / setup.py install completed normally ✅"
fi

# 验证安装 / Verify install
SITE_PKGS=$(python -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "")
if [ -d "$SITE_PKGS/signalp6-6.0+h-py3.7.egg/signalp" ] || \
   pip show signalp6 > /dev/null 2>&1; then
    log_info "✅ signalp 包已安装 / signalp package installed"
else
    log_warn "无法确认安装结果，继续尝试... / Cannot confirm install result, continuing..."
fi

cd "$WORK_DIR"

# ---- [5/8] 安装所有依赖 / Install all dependencies ----
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
pip uninstall -y Pillow pillow 2>/dev/null || true
# 先试 conda（自带兼容 libtiff）/ Try conda first (ships compatible libtiff)
conda install -c conda-forge pillow -y 2>/dev/null || true
if ! python -c "from PIL import Image" 2>/dev/null; then
    log_warn "  conda 安装 Pillow 失败，尝试 pip / conda Pillow failed, trying pip"
    pip install pillow 2>/dev/null || true
    sudo apt-get install -y libtiff5 2>/dev/null || true
fi
python -c "from PIL import Image; print('  Pillow ✅')" 2>/dev/null || log_warn "Pillow 验证失败 / Pillow verification failed"

# 5b. matplotlib
log_info "[5b] 安装 matplotlib..."
MATPLOTLIB_INSTALLED=false
pip install "matplotlib>3.3.2,<4.0" 2>/dev/null && MATPLOTLIB_INSTALLED=true || true
if [ "$MATPLOTLIB_INSTALLED" = "false" ]; then
    log_warn "  pip 安装 matplotlib 失败，尝试 conda / pip matplotlib failed, trying conda..."
    conda install -c conda-forge matplotlib -y 2>/dev/null || true
fi
python -c "import matplotlib; print('  Matplotlib ✅')" 2>/dev/null || log_warn "matplotlib 验证失败 / matplotlib verification failed"

# 5c. NumPy（必须 <2.0，兼容 Python 3.7）/ NumPy (must be <2.0 for Python 3.7)
log_info "[5c] 安装 NumPy（<2.0）/ Installing NumPy (<2.0)..."
pip install "numpy>=1.19,<1.25" || true
python -c "import numpy; print(f'  NumPy {numpy.__version__} ✅')" 2>/dev/null || log_warn "NumPy 验证失败 / NumPy verification failed"

# 5d. PyTorch 1.8.1 CPU 版 / PyTorch 1.8.1 CPU
log_info "[5d] 安装 PyTorch 1.8.1 CPU 版 / Installing PyTorch 1.8.1 CPU..."
PYTORCH_INSTALLED=false

log_info "  尝试 pip 安装 torch 1.8.1+cpu... / Trying pip install torch 1.8.1+cpu..."
pip install torch==1.8.1+cpu torchvision==0.9.1+cpu \
    -f https://download.pytorch.org/whl/torch_stable.html 2>/dev/null
if python -c "import torch; print(f'  PyTorch {torch.__version__} ✅')" 2>/dev/null; then
    log_info "  pip 安装成功，跳过 conda 安装 / pip install succeeded, skipping conda"
    PYTORCH_INSTALLED=true
else
    log_warn "  pip 安装失败，尝试 conda 安装... / pip failed, trying conda..."
    conda install -c pytorch pytorch==1.8.1 cpuonly -y || true
    if python -c "import torch; print(f'  PyTorch {torch.__version__} ✅')" 2>/dev/null; then
        PYTORCH_INSTALLED=true
    fi
fi

if [ "$PYTORCH_INSTALLED" = "false" ]; then
    log_error "PyTorch 安装失败 / PyTorch installation failed，请手动安装 / please install manually"
    echo "  参考命令 / Reference command:" >&2
    echo "    pip install torch==1.8.1+cpu torchvision==0.9.1+cpu -f https://download.pytorch.org/whl/torch_stable.html" >&2
fi

# 5e. tqdm（必须 <4.60，兼容 Python 3.7）/ tqdm (must be <4.60 for Python 3.7)
log_info "[5e] 安装 tqdm（兼容 Python 3.7）/ Installing tqdm (Python 3.7 compat)..."
pip install "tqdm<4.60" || true
python -c "import tqdm; print('  tqdm ✅')" 2>/dev/null || log_warn "tqdm 验证失败 / tqdm verification failed"

# 5f. 最终验证 / Final verification
log_info "[5f] 验证 import signalp... / Verifying import signalp..."
if python -c "import signalp; print('  signalp import ✅')" 2>/dev/null; then
    log_info "✅ 所有依赖安装完成，signalp 可正常导入 / All dependencies installed, signalp importable"
else
    log_error "import signalp 仍然失败 / import signalp still failing，详细错误 / detailed errors:"
    python -c "import signalp" 2>&1 | tail -10
    echo "" >&2
    log_warn "逐个检查依赖状态 / Checking dependencies one by one:" >&2
    python -c "import torch; print('  torch ✅')"      2>/dev/null || log_error "  torch ❌ → pip install torch==1.8.1+cpu -f https://download.pytorch.org/whl/torch_stable.html"
    python -c "from PIL import Image; print('  PIL ✅')" 2>/dev/null || log_error "  Pillow ❌ → conda install -c conda-forge pillow -y"
    python -c "import matplotlib; print('  matplotlib ✅')" 2>/dev/null || log_error "  matplotlib ❌ → pip install 'matplotlib>3.3.2,<4.0'"
    python -c "import tqdm; print('  tqdm ✅')"        2>/dev/null || log_error "  tqdm ❌ → pip install 'tqdm<4.60'"
    echo "" >&2
    log_error "请根据以上提示手动安装缺失包后重试 / Please install missing packages manually and retry"
    exit 1
fi

# ---- [6/8] 部署模型权重 / Deploy model weights ----
log_step "[6/8] 部署模型权重 / Deploy model weights"

SIGNALP_DIR=$(python -c "import signalp; import os; print(os.path.dirname(signalp.__file__))" 2>/dev/null)

if [ -z "$SIGNALP_DIR" ]; then
    log_error "无法获取 SignalP 安装路径 / Cannot get SignalP install path，跳过模型复制 / skipping model copy"
    exit 1
fi

log_info "SignalP 安装路径 / SignalP install path: $SIGNALP_DIR"

MW_DIR="$SIGNALP_DIR/model_weights"
mkdir -p "$MW_DIR"

MW_FILE_COUNT=$(find "$MW_DIR" -type f -not -name "README.md" 2>/dev/null | wc -l)
if [ "$MW_FILE_COUNT" -eq 0 ]; then
    log_info "model_weights/ 当前为空壳（仅有 README.md）/ model_weights/ is empty (README.md only)，需要复制模型 / need to copy models"
else
    log_info "model_weights/ 已有 ${MW_FILE_COUNT} 个文件 / model_weights/ already has ${MW_FILE_COUNT} files"
fi

DEPLOYED_MODES=()
FAILED_MODES=()

for mode in "${TARGET_MODES[@]}"; do
    model_target="${MODEL_FILE_MAP[$mode]}"
    models_dir="${MODELS_DIRS[$mode]:-}"

    log_info "──────────────────────────────"
    log_info "部署 ${mode} 模型 / Deploying ${mode} model: ${model_target}"

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
            target_path="$MW_DIR/$model_target"
            if [ -d "$target_path" ]; then
                FILE_COUNT=$(find "$target_path" -type f | wc -l)
                log_warn "  ${mode} 模型目录已存在 ($FILE_COUNT 文件)，跳过复制 / Model dir already exists, skipping copy"
                DEPLOYED_MODES+=("$mode")
            else
                cp -r "$MODEL_SRC" "$MW_DIR/"
                if [ -d "$MW_DIR/$model_target" ]; then
                    FILE_COUNT=$(find "$MW_DIR/$model_target" -type f | wc -l)
                    TOTAL_SIZE=$(du -sb "$MW_DIR/$model_target" 2>/dev/null | cut -f1)
                    log_info "  ✅ ${mode} 模型复制完成 / Model copy complete: ${FILE_COUNT} 个文件 / files, $(format_size $TOTAL_SIZE)"
                    log_info "     源 / Source: $MODEL_SRC"
                    log_info "     目标 / Target: $MW_DIR/$model_target"
                    DEPLOYED_MODES+=("$mode")
                else
                    log_error "  ❌ ${mode} 模型复制失败 / Model copy failed"
                    FAILED_MODES+=("$mode")
                fi
            fi
        elif [ -f "$MODEL_SRC" ]; then
            target_file="$MW_DIR/$model_target"
            if [ -f "$target_file" ]; then
                EXISTING_SIZE=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null || echo 0)
                log_warn "  ${mode} 模型文件已存在 / Model file already exists ($(format_size $EXISTING_SIZE))，跳过复制 / skipping copy"
                DEPLOYED_MODES+=("$mode")
            else
                cp "$MODEL_SRC" "$MW_DIR/"
                if [ -f "$target_file" ]; then
                    NEW_SIZE=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null || echo 0)
                    log_info "  ✅ ${mode} 模型复制完成 / Model copy complete: $(format_size $NEW_SIZE)"
                    log_info "     源 / Source: $MODEL_SRC"
                    log_info "     目标 / Target: $target_file"
                    DEPLOYED_MODES+=("$mode")
                else
                    log_error "  ❌ ${mode} 模型复制失败 / Model copy failed"
                    FAILED_MODES+=("$mode")
                fi
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
log_info "╔═════════════════════╗"
log_info "║         模型部署汇总 / Model Deployment Summary         ║"
log_info "╠═════════════════════╣"
if [ ${#DEPLOYED_MODES[@]} -gt 0 ]; then
    for dm in "${DEPLOYED_MODES[@]}"; do
        mt="${MODEL_FILE_MAP[$dm]}"
        if [ -d "$MW_DIR/$mt" ]; then
            fc=$(find "$MW_DIR/$mt" -type f | wc -l)
            ts=$(du -sb "$MW_DIR/$mt" 2>/dev/null | cut -f1)
            log_info "║  ✅ ${dm}: ${mt}/ (${fc} 文件 / files, $(format_size $ts))"
        elif [ -f "$MW_DIR/$mt" ]; then
            fs=$(stat -c%s "$MW_DIR/$mt" 2>/dev/null || stat -f%z "$MW_DIR/$mt" 2>/dev/null || echo 0)
            log_info "║  ✅ ${dm}: ${mt} ($(format_size $fs))"
        fi
    done
fi
if [ ${#FAILED_MODES[@]} -gt 0 ]; then
    for fm in "${FAILED_MODES[@]}"; do
        log_error "║  ❌ ${fm}: ${MODEL_FILE_MAP[$fm]} (缺失 / missing)"
    done
    log_warn "║  缺失模式将不可用，可稍后手动补充 / Missing modes will be unavailable, can be added manually later"
fi
log_info "╚═════════════════════╝"

# ---- [7/8] 环境诊断 / Environment diagnostics ----
log_step "[7/8] 环境诊断 / Environment diagnostics"

# 使用 <<'DIAG_SCRIPT' 防止变量展开 / Use quoted heredoc to prevent variable expansion
cat > "$WORK_DIR/check_signalp_env.sh" << 'DIAG_SCRIPT'
#!/bin/bash
echo "╔════════════════════════════════════════════════════════╗"
echo "║           SignalP 6.0 环境诊断报告 (v14)                ║"
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
        # fast
        if [ -f "$MW_DIR/distilled_model_signalp6.pt" ]; then
            SIZE=$(du -sh "$MW_DIR/distilled_model_signalp6.pt" 2>/dev/null | cut -f1)
            echo "   ✅ fast (distilled_model_signalp6.pt) - $SIZE"
        else
            echo "   ❌ fast (distilled_model_signalp6.pt) - 缺失 / missing"
        fi
        # slow-sequential
        if [ -d "$MW_DIR/sequential_models_signalp6" ]; then
            FILE_COUNT=$(find "$MW_DIR/sequential_models_signalp6" -type f | wc -l)
            TOTAL_SIZE=$(du -sh "$MW_DIR/sequential_models_signalp6" 2>/dev/null | cut -f1)
            echo "   ✅ slow-sequential (sequential_models_signalp6/) - ${FILE_COUNT} 文件 / files, ${TOTAL_SIZE}"
        else
            echo "   ❌ slow-sequential (sequential_models_signalp6/) - 缺失 / missing"
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

# ---- [8/8] 最终验证 / Final verification ----
log_step "[8/8] 最终验证 / Final verification"

if conda run -n signalp6 signalp6 --help > /dev/null 2>&1; then
    echo "" >&2
    echo "🎉🎉🎉 安装成功！SignalP 6.0 已就绪 🎉🎉🎉" >&2
    echo "🎉🎉🎉 Installation successful! SignalP 6.0 is ready 🎉🎉🎉" >&2
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
        echo "  signalp6 -i input.fasta -o results -m <${DEPLOYED_MODES[*]}>" >&2
    fi
    echo "" >&2
    echo "故障排查 / Troubleshooting:" >&2
    echo "  conda activate signalp6 && bash $WORK_DIR/check_signalp_env.sh" >&2
else
    echo "" >&2
    echo "❌ signalp6 --help 验证失败 / verification failed" >&2
    echo "" >&2
    echo "请手动排查 / Please troubleshoot manually:" >&2
    echo "  conda activate signalp6" >&2
    echo "  python -c \"import signalp; print('OK')\"" >&2
    echo "  signalp6 --help" >&2
    echo "" >&2
    echo "诊断脚本 / Diagnostic script: bash $WORK_DIR/check_signalp_env.sh" >&2
fi
