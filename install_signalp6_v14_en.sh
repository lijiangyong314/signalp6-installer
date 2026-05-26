#!/bin/bash
# ============================================================
# SignalP 6.0 Fully Automated Installer (v14 English Release)
# SignalP 6.0 Fully Automated Installer (v14 English Release)
# ============================================================
#
# Supported modes:
#   fast            Fast mode - distilled model, fastest speed
#   slow-sequential Slow-sequential - highest accuracy, sequential processing
#
# Usage:
#   ./install_signalp6_v14_en.sh                    # Interactive mode selection
#   ./install_signalp6_v14_en.sh -m fast            # Specify fast mode
#   ./install_signalp6_v14_en.sh -m slow-sequential # Specify slow-sequential
#   ./install_signalp6_v14_en.sh -m all            # Install all available modes
#   ./install_signalp6_v14_en.sh -h                 # Show help
#
# v14 improvements (based on v13 real-machine validation):
#   - English output
#   - All v13 fixes: smart dedup, on-demand extraction, interactive menu, rm -rf safety guard
#   - Fixed parse_tar_filename version parsing (right-to-left split)
#   - Fixed stdout/stderr mixing (all log output to >&2)
#   - Fixed TARGET_MODES duplication
#
# ============================================================

set -uo pipefail

WORK_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)"

# ---- Mode configuration ----
declare -A MODEL_FILE_MAP=(
    ["fast"]="distilled_model_signalp6.pt"
    ["slow-sequential"]="sequential_models_signalp6"
)

declare -A MODE_DESC=(
    ["fast"]="Fast mode - distilled model, fastest speed"
    ["slow-sequential"]="Slow-sequential - highest accuracy, sequential processing"
)

ALL_MODES=("fast" "slow-sequential")

# ---- Utility functions ----

# All log output goes to stderr to avoid capture by $(...)
# All log output goes to stderr to avoid capture by $(...)
log_info()  { echo -e "\033[1;32m[INFO]\033[0m  $1" >&2; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $1" >&2; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; }
log_step()  { echo "" >&2; echo "===== $1 =====" >&2; }

# Format file size
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

# ---- Parse mode and version from filename ----
# Input: signalp-6.0h.fast.tar.gz
# Output: mode version
parse_tar_filename() {
    local filename
    filename=$(basename "$1")
    local base="${filename%.tar.gz}"
    local rest="${base#signalp-}"
    # Version may contain dots (e.g. 6.0h), split from right
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

# ---- Find all tarballs and dedup ----
find_and_dedup_tars() {
    local all_tars=()

    for d in "$HOME/桌面" "$HOME/Desktop" "$HOME/下载" "$HOME/Downloads" "$HOME" "$WORK_DIR" "/tmp" "/opt"; do
        [ -d "$d" ] || continue
        while IFS= read -r -d '' f; do
            all_tars+=("$f")
        done < <(find "$d" -maxdepth 3 -name "signalp-6*.tar.gz" -print0 2>/dev/null)
    done

    # Full disk search (30s timeout)
    while IFS= read -r -d '' f; do
        all_tars+=("$f")
    done < <(timeout 30 find /home -maxdepth 5 -name "signalp-6*.tar.gz" -print0 2>/dev/null || true)

    if [ ${#all_tars[@]} -eq 0 ]; then
        return 1
    fi

    # Deduplicate by path
    local unique_tars=()
    while IFS= read -r f; do
        unique_tars+=("$f")
    done < <(printf '%s\n' "${all_tars[@]}" | sort -u)

    # Parse mode and version for each file
    local parse_tmp=$(mktemp)
    for tf in "${unique_tars[@]}"; do
        local parsed=$(parse_tar_filename "$tf")
        local mode=$(echo "$parsed" | awk '{print $1}')
        local ver=$(echo "$parsed" | awk '{print $2}')
        local size=$(stat -c%s "$tf" 2>/dev/null || stat -f%z "$tf" 2>/dev/null || echo 0)
        echo -e "${mode}\t${ver}\t${size}\t${tf}" >> "$parse_tmp"
    done

    # Group by mode, keep highest version per mode
    local dedup_tmp=$(mktemp)
    for mode in "${ALL_MODES[@]}"; do
        local best=$(grep -P "^${mode}\t" "$parse_tmp" 2>/dev/null | sort -t$'\t' -k2 -Vr | head -n1)
        if [ -n "$best" ]; then
            echo "$best" >> "$dedup_tmp"
        fi
    done

    # Check for unrecognized mode packages
    grep -vP "^($(IFS='|'; echo "${ALL_MODES[*]}"))\t" "$parse_tmp" 2>/dev/null >> "$dedup_tmp" || true

    rm -f "$parse_tmp"
    echo "$dedup_tmp"
}

# ---- Interactive mode selection ----
select_mode_with_packages() {
    local pkg_file="$1"

    echo "" >&2
    echo "========== SignalP 6.0 Install - Please select mode(s) ==========" >&2
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
            echo "       Version: v${ver}  Size: ${size_str}" >&2
            echo "       ${MODE_DESC[$mode]}" >&2
            echo "" >&2
            mode_to_num[$mode_num]="$mode"
            ((mode_num++))
        fi
    done < "$pkg_file"

    local all_num=$mode_num
    echo "  ${all_num}) all  - Install all available modes above" >&2
    echo "" >&2
    echo "============================================================" >&2

    # Input validation loop
    while true; do
        read -p "Select [1-${all_num}], then press Enter: " CHOICE >&2
        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
            echo "  Please enter a number!" >&2
            continue
        fi
        if [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt $all_num ]; then
            echo "  Please enter a number between 1 and ${all_num}!" >&2
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

# ---- CLI argument parsing ----
SELECTED_MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            SELECTED_MODE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-m MODE] [-h]"
            echo ""
            echo "Available modes (depend on found packages):"
            for m in "${ALL_MODES[@]}"; do
                echo "  ${m}  - ${MODE_DESC[$m]}"
            done
            echo "  all    - Install all available model weights"
            echo ""
            echo "Examples:"
            echo "  $0                     # Interactive selection"
            echo "  $0 -m fast             # Install fast mode"
            echo "  $0 -m slow-sequential # Install slow-sequential"
            echo "  $0 -m all              # Install all available"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1 (use -h for help)"
            exit 1
            ;;
    esac
done

# ---- [0/8] Initialize Conda ----
log_step "[0/8] Initialize Conda"
CONDA_BASE=$(conda info --base 2>/dev/null || true)
if [ -z "$CONDA_BASE" ]; then
    log_error "Conda not detected, please install Anaconda/Miniconda first"
    
    exit 1
fi
source "$CONDA_BASE/etc/profile.d/conda.sh"
log_info "Conda path: $CONDA_BASE"

# ---- [1/8] Create Conda environment ----
log_step "[1/8] Create Python environment"

if conda env list 2>/dev/null | grep -q "^signalp6 "; then
    log_warn "signalp6 env already exists, skipping creation"
    log_info "(If rebuild needed: conda remove -n signalp6 --all -y）"
else
    log_info "Creating signalp6 env (python=3.7)..."
    conda create -n signalp6 python=3.7 -c conda-forge -y
fi

# Initialize conda activation function
eval "$(conda shell.bash hook 2>/dev/null)" || {
    log_error "conda shell hook initialization failed"
    exit 1
}
conda activate signalp6 || {
    log_error "conda activate signalp6 failed"
    exit 1
}

PY_IMPL=$(python -c "import platform; print(platform.python_implementation())" 2>/dev/null || echo "unknown")
if [ "$PY_IMPL" != "CPython" ]; then
    log_error "Python implementation is $PY_IMPL, CPython required"
    exit 1
fi
log_info "Python $(python --version 2>&1)，CPython ✅"

# ---- [2/8] Find and parse packages (smart dedup) ----
log_step "[2/8] Find packages (smart dedup)"

DEDUP_FILE=$(find_and_dedup_tars)
DEDUP_RC=$?
if [ $DEDUP_RC -ne 0 ] || [ ! -s "$DEDUP_FILE" ]; then
    rm -f "$DEDUP_FILE"
    log_error "signalp-6*.tar.gz not found"
    echo "" >&2
    read -p "Please enter full path to tarball: " USER_INPUT
    if [ -f "$USER_INPUT" ] && [[ "$USER_INPUT" == *.tar.gz ]]; then
        PARSED=$(parse_tar_filename "$USER_INPUT")
        MANUAL_MODE=$(echo "$PARSED" | awk '{print $1}')
        MANUAL_VER=$(echo "$PARSED" | awk '{print $2}')
        echo -e "${MANUAL_MODE}\t${MANUAL_VER}\t$(stat -c%s "$USER_INPUT" 2>/dev/null || echo 0)\t${USER_INPUT}" > "$DEDUP_FILE"
    else
        log_error "Invalid path, exiting"
        exit 1
    fi
fi

# Show available packages after dedup
log_info "Available packages (highest version per mode):"
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
        log_warn "  ${mode} (v${ver}) -> $path [unrecognized mode]"
    fi
done < "$DEDUP_FILE"

if [ ${#AVAILABLE_MODES[@]} -eq 0 ]; then
    log_error "No recognizable mode packages found"
    rm -f "$DEDUP_FILE"
    exit 1
fi

# ---- Determine modes to install ----
if [ -z "$SELECTED_MODE" ]; then
    # Interactive selection
    CHOSEN=$(select_mode_with_packages "$DEDUP_FILE")
    if [ -z "$CHOSEN" ]; then
        log_error "Invalid selection, exiting"
        rm -f "$DEDUP_FILE"
        exit 1
    fi
    TARGET_MODES=($CHOSEN)
elif [ "$SELECTED_MODE" = "all" ]; then
    TARGET_MODES=("${AVAILABLE_MODES[@]}")
else
    # CLI specified
    if [[ ! " ${ALL_MODES[*]} " =~ " ${SELECTED_MODE} " ]]; then
        log_error "Invalid mode: $SELECTED_MODE"
        log_error "Valid values: ${ALL_MODES[*]}, all"
        rm -f "$DEDUP_FILE"
        exit 1
    fi
    TARGET_MODES=("$SELECTED_MODE")
fi

# Verify selected modes have packages
VALID_TARGETS=()
for tm in "${TARGET_MODES[@]}"; do
    if grep -qP "^${tm}\t" "$DEDUP_FILE" 2>/dev/null; then
        VALID_TARGETS+=("$tm")
    else
        log_warn "Mode ${tm} has no package, skipping"
    fi
done
TARGET_MODES=("${VALID_TARGETS[@]}")

if [ ${#TARGET_MODES[@]} -eq 0 ]; then
    log_error "No installable modes"
    rm -f "$DEDUP_FILE"
    exit 1
fi

log_info "Modes to install: ${TARGET_MODES[*]}"

# ---- [3/8] Extract on demand ----
log_step "[3/8] Extract packages on demand"

declare -A EXTRACTED_PATHS  # mode → extracted source dir / extracted source dir
declare -A MODELS_DIRS      # mode → models/ dir path / models/ dir path
PRIMARY_EXTRACTED=""

for mode in "${TARGET_MODES[@]}"; do
    TAR_PATH=$(grep -P "^${mode}\t" "$DEDUP_FILE" | head -n1 | cut -f4)
    [ -z "$TAR_PATH" ] && continue

    # Extract dir named by mode
    EXTRACT_BASE="$WORK_DIR/signalp_extracted_${mode}"
    # Safety guard：Safety guard against empty var
    if [ -z "$EXTRACT_BASE" ] || [[ "$EXTRACT_BASE" != "$WORK_DIR"* ]]; then
        log_error "Extract path abnormal: '$EXTRACT_BASE', skipping to prevent accidental deletion"
        continue
    fi
    rm -rf "$EXTRACT_BASE"
    mkdir -p "$EXTRACT_BASE"

    log_info "Extracting ${mode} package: $(basename "$TAR_PATH")"
    tar zxf "$TAR_PATH" -C "$EXTRACT_BASE"

    # Find source directory
    SRC=$(find "$EXTRACT_BASE" -type f -name "setup.py" -exec dirname {} \; 2>/dev/null | head -n1)
    if [ -z "$SRC" ]; then
        log_error "setup.py not found after extraction: $(basename "$TAR_PATH")"
        continue
    fi

    EXTRACTED_PATHS[$mode]="$SRC"

    # Record models/ directory
    if [ -d "$SRC/models" ]; then
        MODELS_DIRS[$mode]="$SRC/models"
        log_info "  ${mode} models/ contents:"
        ls -lh "$SRC/models/" 2>/dev/null | sed 's/^/    /'
    fi

    # First mode used for setup.py install
    if [ -z "$PRIMARY_EXTRACTED" ]; then
        PRIMARY_EXTRACTED="$SRC"
        log_info "  → Used as primary package for Python install"
    fi
    echo ""
done

rm -f "$DEDUP_FILE"

if [ -z "$PRIMARY_EXTRACTED" ]; then
    log_error "All packages failed to extract"
    exit 1
fi

# ---- [4/8] Build and install ----
log_step "[4/8] Build and install"

cd "$PRIMARY_EXTRACTED"
log_info "Running python setup.py install (300s timeout)..."
log_warn "Note: may hang after install, script handles it"

set +e
timeout 300 python setup.py install 2>&1 | tee /tmp/signalp_install.log
INSTALL_RC=${PIPESTATUS[0]}
set -e

if [ $INSTALL_RC -eq 124 ]; then
    log_warn "Install timed out at 300s (normal, install complete)"
elif [ $INSTALL_RC -ne 0 ]; then
    log_warn "setup.py exit code $INSTALL_RC (may be normal hang)"
else
    log_info "setup.py install completed normally ✅"
fi

# Verify install
SITE_PKGS=$(python -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "")
if [ -d "$SITE_PKGS/signalp6-6.0+h-py3.7.egg/signalp" ] || \
   pip show signalp6 > /dev/null 2>&1; then
    log_info "signalp package installed ✅"
else
    log_warn "Cannot confirm install result, continuing..."
fi

cd "$WORK_DIR"

# ---- [5/8] Install all dependencies ----
log_step "[5/8] Install all dependencies"

echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "[Important] Install ALL dependencies before import signalp!" >&2
echo "  SignalP import chain: signalp → predict → torch" >&2
echo "                            → make_sequence_plot → matplotlib → PIL" >&2
echo "  Missing any causes ImportError" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2

# 5a. Fix Pillow (libtiff.so.5 issue)
log_info "[5a] Fixing Pillow (libtiff.so.5)..."
pip uninstall -y Pillow pillow 2>/dev/null || true
# Try conda first (ships compatible libtiff)
conda install -c conda-forge pillow -y 2>/dev/null || true
if ! python -c "from PIL import Image" 2>/dev/null; then
    log_warn "  conda Pillow failed, trying pip"
    pip install pillow 2>/dev/null || true
    sudo apt-get install -y libtiff5 2>/dev/null || true
fi
python -c "from PIL import Image; print('  Pillow ✅')" 2>/dev/null || log_warn "Pillow verification failed"

# 5b. matplotlib
log_info "[5b] Installing matplotlib..."
MATPLOTLIB_INSTALLED=false
pip install "matplotlib>3.3.2,<4.0" 2>/dev/null && MATPLOTLIB_INSTALLED=true || true
if [ "$MATPLOTLIB_INSTALLED" = "false" ]; then
    log_warn "  pip matplotlib failed, trying conda..."
    conda install -c conda-forge matplotlib -y 2>/dev/null || true
fi
python -c "import matplotlib; print('  Matplotlib ✅')" 2>/dev/null || log_warn "matplotlib verification failed"

# 5c. NumPy (must be <2.0 for Python 3.7)
log_info "[5c] Installing NumPy (<2.0)..."
pip install "numpy>=1.19,<1.25" || true
python -c "import numpy; print(f'  NumPy {numpy.__version__} ✅')" 2>/dev/null || log_warn "NumPy verification failed"

# 5d. PyTorch 1.8.1 CPU PyTorch 1.8.1 CPU
log_info "[5d] Installing PyTorch 1.8.1 CPU..."
PYTORCH_INSTALLED=false

log_info "  Trying pip install torch 1.8.1+cpu..."
pip install torch==1.8.1+cpu torchvision==0.9.1+cpu \
    -f https://download.pytorch.org/whl/torch_stable.html 2>/dev/null
if python -c "import torch; print(f'  PyTorch {torch.__version__} ✅')" 2>/dev/null; then
    log_info "  pip install succeeded, skipping conda"
    PYTORCH_INSTALLED=true
else
    log_warn "  pip failed, trying conda..."
    conda install -c pytorch pytorch==1.8.1 cpuonly -y || true
    if python -c "import torch; print(f'  PyTorch {torch.__version__} ✅')" 2>/dev/null; then
        PYTORCH_INSTALLED=true
    fi
fi

if [ "$PYTORCH_INSTALLED" = "false" ]; then
    log_error "PyTorch installation failed, please install manually"
    echo "  Reference command:" >&2
    echo "    pip install torch==1.8.1+cpu torchvision==0.9.1+cpu -f https://download.pytorch.org/whl/torch_stable.html" >&2
fi

# 5e. tqdm (must be <4.60 for Python 3.7)
log_info "[5e] Installing tqdm (Python 3.7 compat)..."
pip install "tqdm<4.60" || true
python -c "import tqdm; print('  tqdm ✅')" 2>/dev/null || log_warn "tqdm verification failed"

# 5f. Final verification
log_info "[5f] Verifying import signalp..."
if python -c "import signalp; print('  signalp import ✅')" 2>/dev/null; then
    log_info "All dependencies installed, signalp importable ✅"
else
    log_error "import signalp still failing, detailed errors:"
    python -c "import signalp" 2>&1 | tail -10
    echo "" >&2
    log_warn "Checking dependencies one by one:" >&2
    python -c "import torch; print('  torch ✅')"      2>/dev/null || log_error "  torch ❌ → pip install torch==1.8.1+cpu -f https://download.pytorch.org/whl/torch_stable.html"
    python -c "from PIL import Image; print('  PIL ✅')" 2>/dev/null || log_error "  Pillow ❌ → conda install -c conda-forge pillow -y"
    python -c "import matplotlib; print('  matplotlib ✅')" 2>/dev/null || log_error "  matplotlib ❌ → pip install 'matplotlib>3.3.2,<4.0'"
    python -c "import tqdm; print('  tqdm ✅')"        2>/dev/null || log_error "  tqdm ❌ → pip install 'tqdm<4.60'"
    echo "" >&2
    log_error "Please install missing packages manually and retry"
    exit 1
fi

# ---- [6/8] Deploy model weights ----
log_step "[6/8] Deploy model weights"

SIGNALP_DIR=$(python -c "import signalp; import os; print(os.path.dirname(signalp.__file__))" 2>/dev/null)

if [ -z "$SIGNALP_DIR" ]; then
    log_error "Cannot get SignalP install path, skipping model copy"
    exit 1
fi

log_info "SignalP install path: $SIGNALP_DIR"

MW_DIR="$SIGNALP_DIR/model_weights"
mkdir -p "$MW_DIR"

MW_FILE_COUNT=$(find "$MW_DIR" -type f -not -name "README.md" 2>/dev/null | wc -l)
if [ "$MW_FILE_COUNT" -eq 0 ]; then
    log_info "model_weights/ is empty (README.md only), need to copy models"
else
    log_info "model_weights/ already has ${MW_FILE_COUNT} files"
fi

DEPLOYED_MODES=()
FAILED_MODES=()

for mode in "${TARGET_MODES[@]}"; do
    model_target="${MODEL_FILE_MAP[$mode]}"
    models_dir="${MODELS_DIRS[$mode]:-}"

    log_info "──────────────────────────────"
    log_info "Deploying ${mode} model: ${model_target}"

    MODEL_SRC=""

    # First: exact match from this mode's extract dir
    if [ -n "$models_dir" ] && [ -d "$models_dir" ]; then
        if [ -f "$models_dir/$model_target" ]; then
            MODEL_SRC="$models_dir/$model_target"
            log_info "  Exact match (file): $MODEL_SRC"
        elif [ -d "$models_dir/$model_target" ]; then
            MODEL_SRC="$models_dir/$model_target"
            log_info "  Exact match (dir): $MODEL_SRC"
        fi
    fi

    # If not found in this mode's dir, search other extracted dirs
    if [ -z "$MODEL_SRC" ]; then
        for other_mode in "${!MODELS_DIRS[@]}"; do
            [ "$other_mode" = "$mode" ] && continue
            omd="${MODELS_DIRS[$other_mode]}"
            [ -z "$omd" ] || [ ! -d "$omd" ] && continue
            if [ -f "$omd/$model_target" ]; then
                MODEL_SRC="$omd/$model_target"
                log_info "  Found in ${other_mode} package: $MODEL_SRC"
                break
            elif [ -d "$omd/$model_target" ]; then
                MODEL_SRC="$omd/$model_target"
                log_info "  Found in ${other_mode} package: $MODEL_SRC"
                break
            fi
        done
    fi

    # Full disk search fallback
    if [ -z "$MODEL_SRC" ]; then
        log_warn "  Not found in extracted dirs, starting full search..."
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
            log_info "  Found by full search: $MODEL_SRC"
        fi
    fi

    # Execute copy
    if [ -n "$MODEL_SRC" ]; then
        if [ -d "$MODEL_SRC" ]; then
            target_path="$MW_DIR/$model_target"
            if [ -d "$target_path" ]; then
                FILE_COUNT=$(find "$target_path" -type f | wc -l)
                log_warn "  ${mode} model dir already exists (${FILE_COUNT} files), skipping"
                DEPLOYED_MODES+=("$mode")
            else
                cp -r "$MODEL_SRC" "$MW_DIR/"
                if [ -d "$MW_DIR/$model_target" ]; then
                    FILE_COUNT=$(find "$MW_DIR/$model_target" -type f | wc -l)
                    TOTAL_SIZE=$(du -sb "$MW_DIR/$model_target" 2>/dev/null | cut -f1)
                    log_info "  ✅ ${mode} model copy complete: ${FILE_COUNT} files, $(format_size $TOTAL_SIZE)"
                    log_info "     Source: $MODEL_SRC"
                    log_info "     Target: $MW_DIR/$model_target"
                    DEPLOYED_MODES+=("$mode")
                else
                    log_error "  ❌ ${mode} model copy failed"
                    FAILED_MODES+=("$mode")
                fi
            fi
        elif [ -f "$MODEL_SRC" ]; then
            target_file="$MW_DIR/$model_target"
            if [ -f "$target_file" ]; then
                EXISTING_SIZE=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null || echo 0)
                log_warn "  ${mode} model file already exists ($(format_size $EXISTING_SIZE)), skipping"
                DEPLOYED_MODES+=("$mode")
            else
                cp "$MODEL_SRC" "$MW_DIR/"
                if [ -f "$target_file" ]; then
                    NEW_SIZE=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null || echo 0)
                    log_info "  ✅ ${mode} Model copy complete: $(format_size $NEW_SIZE)"
                    log_info "     Source: $MODEL_SRC"
                    log_info "     Target: $target_file"
                    DEPLOYED_MODES+=("$mode")
                else
                    log_error "  ❌ ${mode} model copy failed"
                    FAILED_MODES+=("$mode")
                fi
            fi
        fi
    else
        log_error "  ❌ Model not found: ${model_target}"
        FAILED_MODES+=("$mode")
        echo "" >&2
        read -p "    Enter full path to ${model_target} (or Enter to skip): " USER_MODEL
        if [ -n "$USER_MODEL" ] && ([ -d "$USER_MODEL" ] || [ -f "$USER_MODEL" ]); then
            cp -r "$USER_MODEL" "$MW_DIR/"
            if [ -e "$MW_DIR/$model_target" ]; then
                log_info "  ✅ ${mode} manual model copy complete"
                DEPLOYED_MODES+=("$mode")
                FAILED_MODES=("${FAILED_MODES[@]/$mode}")
            fi
        else
            log_warn "  Skipping ${mode} model copy"
        fi
    fi
    echo "" >&2
done

# Model deployment summary
log_info "╔═════════════════════════════════╗"
log_info "║         Model Deployment Summary          ║"
log_info "╠═════════════════════════════════╣"
if [ ${#DEPLOYED_MODES[@]} -gt 0 ]; then
    for dm in "${DEPLOYED_MODES[@]}"; do
        mt="${MODEL_FILE_MAP[$dm]}"
        if [ -d "$MW_DIR/$mt" ]; then
            fc=$(find "$MW_DIR/$mt" -type f | wc -l)
            ts=$(du -sb "$MW_DIR/$mt" 2>/dev/null | cut -f1)
            log_info "║  ✅ ${dm}: ${mt}/ (${fc} files / files, $(format_size $ts))"
        elif [ -f "$MW_DIR/$mt" ]; then
            fs=$(stat -c%s "$MW_DIR/$mt" 2>/dev/null || stat -f%z "$MW_DIR/$mt" 2>/dev/null || echo 0)
            log_info "║  ✅ ${dm}: ${mt} ($(format_size $fs))"
        fi
    done
fi
if [ ${#FAILED_MODES[@]} -gt 0 ]; then
    for fm in "${FAILED_MODES[@]}"; do
        log_error "║  ❌ ${fm}: ${MODEL_FILE_MAP[$fm]} (missing)"
    done
    log_warn "║  Missing modes unavailable, can add manually later"
fi
log_info "╚═════════════════════════════════╝"

# ---- [7/8] Environment diagnostics ----
log_step "[7/8] Environment diagnostics"

# Use quoted heredoc to prevent variable expansion
cat > "$WORK_DIR/check_signalp_env.sh" << 'DIAG_SCRIPT'
#!/bin/bash
echo "╔════════════════════════════════════════════════════════╗"
echo "║           SignalP 6.0 Environment Diagnostics (v14)              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "1. Python Python environment:"
python --version 2>&1
python -c "import platform; print('   Implementation:', platform.python_implementation())" 2>/dev/null
echo ""
echo "2. Core dependencies:"
python -c "import numpy; print('   NumPy:      ', numpy.__version__)"    2>/dev/null || echo "   ❌ NumPy"
python -c "import torch; print('   PyTorch:    ', torch.__version__)"    2>/dev/null || echo "   ❌ PyTorch"
python -c "import PIL; print('   Pillow:     ', PIL.__version__)"       2>/dev/null || echo "   ❌ Pillow"
python -c "import matplotlib; print('   Matplotlib: ', matplotlib.__version__)" 2>/dev/null || echo "   ❌ Matplotlib"
python -c "import tqdm; print('   tqdm:       OK')"                    2>/dev/null || echo "   ❌ tqdm"
echo ""
echo "3. SignalP SignalP status:"
SIGNALP_PATH=$(python -c "import signalp; print(signalp.__file__)" 2>/dev/null || true)
if [ -n "$SIGNALP_PATH" ]; then
    echo "   ✅ import signalp success / success: $SIGNALP_PATH"
    SIGNALP_DIR=$(dirname "$SIGNALP_PATH")
    MW_DIR="$SIGNALP_DIR/model_weights"
    echo ""
    echo "4. Model weights status (model_weights/):"
    if [ -d "$MW_DIR" ]; then
        echo "   Dir: $MW_DIR"
        echo ""
        # fast
        if [ -f "$MW_DIR/distilled_model_signalp6.pt" ]; then
            SIZE=$(du -sh "$MW_DIR/distilled_model_signalp6.pt" 2>/dev/null | cut -f1)
            echo "   ✅ fast (distilled_model_signalp6.pt) - $SIZE"
        else
            echo "   ❌ fast (distilled_model_signalp6.pt) - missing / missing"
        fi
        # slow-sequential
        if [ -d "$MW_DIR/sequential_models_signalp6" ]; then
            FILE_COUNT=$(find "$MW_DIR/sequential_models_signalp6" -type f | wc -l)
            TOTAL_SIZE=$(du -sh "$MW_DIR/sequential_models_signalp6" 2>/dev/null | cut -f1)
            echo "   ✅ slow-sequential (sequential_models_signalp6/) - ${FILE_COUNT} files / files, ${TOTAL_SIZE}"
        else
            echo "   ❌ slow-sequential (sequential_models_signalp6/) - missing / missing"
        fi
    else
        echo "   ❌ model_weights Dirmissing / model_weights dir missing"
    fi
else
    echo "   ❌ import signalp failed / failed"
fi
echo ""
echo "5. signalp6 command / signalp6 command:"
which signalp6 2>/dev/null && echo "   ✅ signalp6 in PATH" || echo "   ❌ signalp6 not in PATH"
echo ""
echo "════════════════════ Diagnostics complete ═══════════════"
DIAG_SCRIPT

chmod +x "$WORK_DIR/check_signalp_env.sh"
bash "$WORK_DIR/check_signalp_env.sh"

# ---- [8/8] Final verification ----
log_step "[8/8] Final verification"

if conda run -n signalp6 signalp6 --help > /dev/null 2>&1; then
    echo "" >&2
    echo "🎉🎉🎉 Installation successful! SignalP 6.0 is ready 🎉🎉🎉" >&2
    echo "🎉🎉🎉 Installation successful! SignalP 6.0 is ready 🎉🎉🎉" >&2
    echo "" >&2
    echo "Installed modes:" >&2
    for dm in "${DEPLOYED_MODES[@]}"; do
        echo "  ✅ ${dm} - ${MODE_DESC[$dm]}" >&2
    done
    if [ ${#FAILED_MODES[@]} -gt 0 ]; then
        echo "" >&2
        echo "Missing modes (need to manually add model weights to $MW_DIR/):" >&2
        for fm in "${FAILED_MODES[@]}"; do
            echo "  ❌ ${fm} → need / need: ${MODEL_FILE_MAP[$fm]}" >&2
        done
    fi
    echo "" >&2
    echo "Usage:" >&2
    echo "  conda activate signalp6" >&2
    if [ ${#DEPLOYED_MODES[@]} -eq 1 ]; then
        echo "  signalp6 -i input.fasta -o results -m ${DEPLOYED_MODES[0]}" >&2
    else
        echo "  signalp6 -i input.fasta -o results -m <${DEPLOYED_MODES[*]}>" >&2
    fi
    echo "" >&2
    echo "Troubleshooting:" >&2
    echo "  conda activate signalp6 && bash $WORK_DIR/check_signalp_env.sh" >&2
else
    echo "" >&2
    echo "❌ signalp6 --help verification failed / verification failed" >&2
    echo "" >&2
    echo "Please troubleshoot manually:" >&2
    echo "  conda activate signalp6" >&2
    echo "  python -c \"import signalp; print('OK')\"" >&2
    echo "  signalp6 --help" >&2
    echo "" >&2
    echo "Diagnostic script: bash $WORK_DIR/check_signalp_env.sh" >&2
fi
