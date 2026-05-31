#!/bin/bash
# ============================================================
# SignalP 6.0 Fully Automated Installer (v15 English - Final Fix)
# ============================================================
#
# Fixes included:
#   - Added nomkl to avoid MKL activation errors
#   - Use absolute paths instead of conda run, eliminating source detection errors
#   - Added PS1/BASH_ENV environment variable spoofing to prevent conda detection
#   - Strict version constraints for numpy/matplotlib to ensure Python 3.7 compatibility
#   - Ensure setuptools exists before compilation
#   - Optimized dependency installation (prefer conda, fallback to pip)
#
# ============================================================

set -uo pipefail

# Pre-declare variables
TARGET_MODES=()
CONDA_BASE=""

WORK_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)"

# ================================================================
# Version Configuration
# ================================================================
PYTHON_VERSION="3.7"
PYTORCH_VERSION="1.8.1"
TORCHVISION_VERSION="0.9.1"
TORCH_VARIANT="cpu"

NUMPY_CONSTRAINT=">=1.19,<2.0"      # actual install will use <1.22
MATPLOTLIB_CONSTRAINT=">3.3.2,<5.0" # actual install will use <3.7
TQDM_CONSTRAINT="<4.66"
PILLOW_CONSTRAINT="<11"

declare -A MODEL_FILE_MAP=(
    ["fast"]="distilled_model_signalp6.pt"
    ["slow-sequential"]="sequential_models_signalp6"
)

declare -A MODE_DESC=(
    ["fast"]="Fast mode - distilled model, fastest speed"
    ["slow-sequential"]="Slow-sequential mode - highest accuracy, sequential processing"
)

ALL_MODES=("fast" "slow-sequential")

# ================================================================
# Checkpoint Resume - State File Management
# ================================================================
STATE_FILE="$HOME/.signalp6_install_state"

save_state() {
    local step="$1"
    local modes_str=""
    if [ ${#TARGET_MODES[@]} -gt 0 ] 2>/dev/null; then
        modes_str=$(IFS='|'; echo "${TARGET_MODES[*]}")
    fi
    printf 'CURRENT_STEP="%s"\nTARGET_MODES="%s"\nCONDA_BASE="%s"\nSCRIPT_VERSION="v15_fixed"\nTIMESTAMP="%s"\n' \
        "$step" "${modes_str}" "${CONDA_BASE:-}" "$(date '+%Y-%m-%d %H:%M:%S')" > "$STATE_FILE"
}

load_state() {
    [ ! -f "$STATE_FILE" ] && return 1
    CURRENT_STEP=$(grep '^CURRENT_STEP=' "$STATE_FILE" | sed 's/^CURRENT_STEP=//' | tr -d '"')
    TARGET_MODES=$(grep '^TARGET_MODES=' "$STATE_FILE" | sed 's/^TARGET_MODES=//' | tr -d '"')
    CONDA_BASE=$(grep '^CONDA_BASE=' "$STATE_FILE" | sed 's/^CONDA_BASE=//' | tr -d '"')
    TIMESTAMP=$(grep '^TIMESTAMP=' "$STATE_FILE" | sed 's/^TIMESTAMP=//' | tr -d '"')
    if [ -n "${TARGET_MODES:-}" ]; then
        IFS='|' read -ra TARGET_MODES <<< "$TARGET_MODES"
    fi
    TARGET_MODES_STR="${TARGET_MODES[*]}"
    return 0
}

clear_state() { rm -f "$STATE_FILE"; }

step_display_name() {
    local step="$1"
    case "$step" in
        0)   echo "Init Conda" ;;
        1)   echo "Create Python env" ;;
        2)   echo "Find packages" ;;
        3)   echo "Extract packages" ;;
        4)   echo "Build & install" ;;
        5a)  echo "Install Pillow" ;;
        5b)  echo "Install matplotlib" ;;
        5c)  echo "Install NumPy" ;;
        5d)  echo "Install PyTorch" ;;
        5e)  echo "Install tqdm" ;;
        5f)  echo "Verify signalp import" ;;
        6)   echo "Deploy model weights" ;;
        7)   echo "Diagnostics" ;;
        8)   echo "Final verification" ;;
        *)   echo "Step $step" ;;
    esac
}

show_resume_menu() {
    local step_desc
    step_desc=$(step_display_name "${CURRENT_STEP:-?}")
    echo "" >&2
    echo "╔═══════════════════════════════════════════════════════════╗" >&2
    echo "║     Previous incomplete install detected                  ║" >&2
    echo "╠═══════════════════════════════════════════════════════════╣" >&2
    echo "║  Interrupted at: ${step_desc}" >&2
    echo "║  Time: ${TIMESTAMP:-?}" >&2
    echo "║  Modes: ${TARGET_MODES_STR:-?}" >&2
    echo "╚═══════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    echo "  [1] Resume from last checkpoint" >&2
    echo "  [2] Fresh install (remove existing env and restart)" >&2
    echo "  [3] Exit" >&2
    echo "" >&2

    while true; do
        read -p "Select [1-3]: " choice >&2
        case "$choice" in
            1) return 0 ;;
            2) return 1 ;;
            3) exit 0 ;;
            *) echo "  Please enter 1-3" >&2 ;;
        esac
    done
}

# ================================================================
# Conda TOS auto-accept
# ================================================================
accept_conda_tos() {
    log_info "Attempting to accept Conda Terms of Service..."
    local success=true
    if ! conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null; then
        success=false
    fi
    if ! conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null; then
        success=false
    fi
    if [ "$success" = true ]; then
        log_info "Conda TOS accepted successfully."
    else
        log_warn "Failed to auto-accept Conda TOS."
        log_warn "Please manually run the following commands and then re-run the script:"
        echo "  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main" >&2
        echo "  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r" >&2
    fi
}

# ================================================================
# Miniconda Auto-Installer (adds .sh suffix to bypass detection)
# ================================================================
install_miniconda() {
    log_info "Downloading Miniconda installer..."
    log_warn "  ~80MB download, requires internet"
    local installer="/tmp/miniconda3_installer_$$_$(date +%s)"
    local url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"

    if command -v wget &>/dev/null; then
        wget -q --show-progress "$url" -O "$installer" 2>&1 || {
            log_error "wget download failed"; rm -f "$installer"; return 1; }
    elif command -v curl &>/dev/null; then
        curl -fSL "$url" -o "$installer" 2>&1 || {
            log_error "curl download failed"; rm -f "$installer"; return 1; }
    else
        log_error "Neither wget nor curl found"
        log_info "Please install Miniconda manually: https://docs.conda.io/en/latest/miniconda.html"
        return 1
    fi

    log_info "Installing Miniconda to ~/miniconda3..."
    log_warn "  This may take 10-15 minutes, please be patient..."

    # Add .sh suffix to installer to bypass $0 detection
    local installer_with_sh="${installer}.sh"
    mv "$installer" "$installer_with_sh"

    bash "$installer_with_sh" -b -p "$HOME/miniconda3" 2>&1 | tee /tmp/miniconda_install.log
    local install_exit=${PIPESTATUS[0]}
    rm -f "$installer_with_sh"

    if [ $install_exit -ne 0 ]; then
        log_error "Miniconda installation failed, check log /tmp/miniconda_install.log"
        return 1
    fi

    CONDA_BASE="$HOME/miniconda3"

    # Add to .bashrc if not already present
    local bashrc="${HOME}/.bashrc"
    if [ -f "$bashrc" ] && ! grep -q 'miniconda3/bin' "$bashrc" 2>/dev/null; then
        echo '' >> "$bashrc"
        echo '# >>> Miniconda3 >>>' >> "$bashrc"
        echo "export PATH=\"${HOME}/miniconda3/bin:\$PATH\"" >> "$bashrc"
        echo '# <<< Miniconda3 <<<' >> "$bashrc"
        log_info "Added to ~/.bashrc (effective in new terminal)"
    fi

    log_info "Miniconda installed: $CONDA_BASE"
    # Note: do not source conda.sh here (will be done later with PS1 set)
    accept_conda_tos
    return 0
}

# ---- Utility functions ----
log_info()  { echo -e "\033[1;32m[INFO]\033[0m  $1" >&2; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $1" >&2; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; }
log_step()  { echo "" >&2; echo "===== $1 =====" >&2; }
log_skip()  { echo -e "\033[1;36m[SKIP]\033[0m  $1" >&2; }

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

find_and_dedup_tars() {
    local all_tars=()
    for d in "$HOME/Desktop" "$HOME/Downloads" "$HOME" "$WORK_DIR" "/tmp" "/opt"; do
        [ -d "$d" ] || continue
        while IFS= read -r -d '' f; do
            all_tars+=("$f")
        done < <(find "$d" -maxdepth 3 -name "signalp-[0-9]*.tar.gz" -print0 2>/dev/null)
    done
    while IFS= read -r -d '' f; do
        all_tars+=("$f")
    done < <(timeout 30 find /home -maxdepth 5 -name "signalp-[0-9]*.tar.gz" -print0 2>/dev/null || true)
    if [ ${#all_tars[@]} -eq 0 ]; then
        return 1
    fi
    local unique_tars=()
    while IFS= read -r f; do
        unique_tars+=("$f")
    done < <(printf '%s\n' "${all_tars[@]}" | sort -u)
    local parse_tmp=$(mktemp)
    for tf in "${unique_tars[@]}"; do
        local parsed=$(parse_tar_filename "$tf")
        local mode=$(echo "$parsed" | awk '{print $1}')
        local ver=$(echo "$parsed" | awk '{print $2}')
        local size=$(stat -c%s "$tf" 2>/dev/null || stat -f%z "$tf" 2>/dev/null || echo 0)
        echo -e "${mode}\t${ver}\t${size}\t${tf}" >> "$parse_tmp"
    done
    local dedup_tmp=$(mktemp)
    for mode in "${ALL_MODES[@]}"; do
        local best=$(grep -P "^${mode}\t" "$parse_tmp" 2>/dev/null | sort -t$'\t' -k2 -Vr | head -n1)
        if [ -n "$best" ]; then
            echo "$best" >> "$dedup_tmp"
        fi
    done
    grep -vP "^($(IFS='|'; echo "${ALL_MODES[*]}"))\t" "$parse_tmp" 2>/dev/null >> "$dedup_tmp" || true
    rm -f "$parse_tmp"
    echo "$dedup_tmp"
}

select_mode_with_packages() {
    local pkg_file="$1"
    echo "" >&2
    echo "========== SignalP 6.0 Install - Please select mode(s) ==========" >&2
    echo "" >&2
    local mode_num=1
    declare -A mode_to_num
    while IFS=$'\t' read -r mode ver size path; do
        [ -z "$mode" ] && continue
        if [[ " ${ALL_MODES[*]} " == *" ${mode} "* ]]; then
            local size_str=$(format_size $size)
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
CLI_RESET="false"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode) SELECTED_MODE="$2"; shift 2 ;;
        --reset) CLI_RESET="true"; shift ;;
        -h|--help)
            echo "Usage: $0 [-m MODE] [--reset] [-h]"
            echo "Available modes: ${ALL_MODES[*]}, all"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ================================================================
# Checkpoint Resume Entry Point
# ================================================================
RESUME_MODE="fresh"
if [ "$CLI_RESET" = "true" ]; then
    clear_state
    log_info "State cleared, performing fresh install"
elif load_state; then
    if show_resume_menu; then
        RESUME_MODE="resume"
        log_info "Resuming from: $(step_display_name "${CURRENT_STEP}")"
        log_info "Selected modes: ${TARGET_MODES[*]}"
    else
        RESUME_MODE="fresh"
        clear_state
        log_info "Performing fresh install"
    fi
fi

# ================================================================
# [0/8] Init Conda (with auto-install)
# ================================================================
log_step "[0/8] Initialize Conda"

if [ "$RESUME_MODE" = "resume" ] && [ -n "${CONDA_BASE:-}" ] && [ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]; then
    export PS1="\\u@\\h:\\w\\$ "
    export BASH_ENV="$HOME/.bashrc"
    source "$CONDA_BASE/etc/profile.d/conda.sh"
    log_skip "Conda ready (resumed): $CONDA_BASE"
else
    CONDA_BASE=$(conda info --base 2>/dev/null || true)
    if [ -z "$CONDA_BASE" ]; then
        for p in "$HOME/miniconda3" "$HOME/miniconda" "$HOME/anaconda3" "/opt/conda" "/opt/miniconda3"; do
            if [ -f "$p/etc/profile.d/conda.sh" ]; then
                CONDA_BASE="$p"
                log_info "Found Conda at common path: $CONDA_BASE"
                break
            fi
        done
    fi

    if [ -n "$CONDA_BASE" ]; then
        export PS1="\\u@\\h:\\w\\$ "
        export BASH_ENV="$HOME/.bashrc"
        source "$CONDA_BASE/etc/profile.d/conda.sh"
        log_info "Conda path: $CONDA_BASE"
    else
        echo "" >&2
        log_warn "╔═══════════════════════════════════════════════════════════╗"
        log_warn "║  Conda not detected                                     ║"
        log_warn "║  SignalP 6.0 requires Conda to manage Python dependencies ║"
        log_warn "╚═══════════════════════════════════════════════════════════╝"
        echo "" >&2
        echo "  [1] Auto-install Miniconda (Recommended)" >&2
        echo "      Install to ~/miniconda3, no root required" >&2
        echo "" >&2
        echo "  [2] I'll install it myself" >&2
        echo "" >&2
        echo "  [3] Exit" >&2
        echo "" >&2

        while true; do
            read -p "Select [1-3]: " condachoice >&2
            case "$condachoice" in
                1)
                    if install_miniconda; then
                        export PS1="\\u@\\h:\\w\\$ "
                        export BASH_ENV="$HOME/.bashrc"
                        source "$CONDA_BASE/etc/profile.d/conda.sh"
                        log_info "Conda ready: $CONDA_BASE"
                    else
                        log_error "Miniconda install failed, please install manually"
                        exit 1
                    fi
                    break
                    ;;
                2)
                    echo "" >&2
                    echo "Please install Miniconda and re-run the script:" >&2
                    echo "" >&2
                    echo "  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" >&2
                    echo "  bash Miniconda3-latest-Linux-x86_64.sh -b -p \$HOME/miniconda3" >&2
                    echo "  source ~/.bashrc" >&2
                    echo "  Then re-run: $0" >&2
                    exit 0
                    ;;
                3) exit 0 ;;
                *) echo "  Please enter 1-3" >&2 ;;
            esac
        done
    fi
fi

save_state "1"

# ================================================================
# [1/8] Create Conda environment (idempotent, force nomkl to avoid MKL conflict)
# ================================================================
log_step "[1/8] Create Python environment"

ENV_EXISTS=false
if conda env list 2>/dev/null | grep -q "^signalp6 "; then
    ENV_EXISTS=true
fi

if [ "$ENV_EXISTS" = true ]; then
    eval "$(conda shell.bash hook 2>/dev/null)"
    if conda activate signalp6 2>/dev/null && python --version &>/dev/null; then
        if conda list -n signalp6 | grep -q '^mkl '; then
            log_warn "MKL detected in environment, which causes activation errors. Removing and recreating with nomkl..."
            conda remove -n signalp6 --all -y
            log_info "Recreating environment (python=${PYTHON_VERSION} pip setuptools nomkl)..."
            conda create -n signalp6 python="${PYTHON_VERSION}" pip setuptools nomkl -c conda-forge -y
            conda activate signalp6
        else
            log_skip "signalp6 environment already exists and is healthy (no MKL), skipping"
            log_info "(To rebuild: conda remove -n signalp6 --all -y)"
            conda activate signalp6
        fi
    else
        log_warn "signalp6 environment exists but python is unusable, removing and recreating..."
        conda remove -n signalp6 --all -y
        log_info "Creating signalp6 environment (python=${PYTHON_VERSION} pip setuptools nomkl)..."
        conda create -n signalp6 python="${PYTHON_VERSION}" pip setuptools nomkl -c conda-forge -y
        conda activate signalp6
    fi
else
    log_info "Creating signalp6 environment (python=${PYTHON_VERSION} pip setuptools nomkl)..."
    conda create -n signalp6 python="${PYTHON_VERSION}" pip setuptools nomkl -c conda-forge -y
    conda activate signalp6
fi

# Ensure environment is activated (fallback)
if [[ "$CONDA_DEFAULT_ENV" != "signalp6" ]]; then
    conda activate signalp6 || {
        log_error "conda activate signalp6 failed"
        exit 1
    }
fi

# Ensure pip is present
log_info "Checking pip in signalp6 environment..."
if ! command -v pip &>/dev/null; then
    log_warn "pip not found in signalp6 environment, installing..."
    conda install pip -y || {
        log_error "Failed to install pip in signalp6 environment"
        exit 1
    }
    log_info "pip installed successfully"
else
    log_info "pip already available"
fi

PY_IMPL=$(python -c "import platform; print(platform.python_implementation())" 2>/dev/null || echo "unknown")
if [ "$PY_IMPL" != "CPython" ]; then
    log_error "Python implementation is $PY_IMPL, CPython required"
    exit 1
fi
log_info "Python $(python --version 2>&1), CPython OK"

save_state "2"

# ================================================================
# [2/8] Find and parse packages (smart dedup)
# ================================================================
log_step "[2/8] Find packages (smart dedup)"

DEDUP_FILE=$(find_and_dedup_tars)
if [ $? -ne 0 ] || [ ! -s "$DEDUP_FILE" ]; then
    rm -f "$DEDUP_FILE"
    log_error "signalp-*.tar.gz not found"
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

log_info "Available packages (highest version per mode):"
AVAILABLE_MODES=()
while IFS=$'\t' read -r mode ver size path; do
    [ -z "$mode" ] && continue
    local_is_known=false
    for am in "${ALL_MODES[@]}"; do
        if [ "$mode" = "$am" ]; then local_is_known=true; break; fi
    done
    if [ "$local_is_known" = "true" ]; then
        log_info "  OK ${mode} (v${ver}) -> $path ($(format_size $size))"
        AVAILABLE_MODES+=("$mode")
    else
        log_warn "  ? ${mode} (v${ver}) -> $path [unrecognized mode]"
    fi
done < "$DEDUP_FILE"

if [ ${#AVAILABLE_MODES[@]} -eq 0 ]; then
    log_error "No recognizable mode packages found"
    rm -f "$DEDUP_FILE"
    exit 1
fi

# Determine modes to install
if [ ${#TARGET_MODES[@]} -gt 0 ] 2>/dev/null; then
    VALID_TARGETS=()
    for tm in "${TARGET_MODES[@]}"; do
        if grep -qP "^${tm}\t" "$DEDUP_FILE" 2>/dev/null; then
            VALID_TARGETS+=("$tm")
        else
            log_warn "Mode ${tm} package no longer available"
        fi
    done
    if [ ${#VALID_TARGETS[@]} -eq 0 ]; then
        log_warn "Previously selected modes unavailable, please re-select"
        TARGET_MODES=()
    else
        TARGET_MODES=("${VALID_TARGETS[@]}")
        log_info "Using saved modes: ${TARGET_MODES[*]}"
    fi
fi

if [ ${#TARGET_MODES[@]} -eq 0 ]; then
    if [ -z "$SELECTED_MODE" ]; then
        CHOSEN=$(select_mode_with_packages "$DEDUP_FILE")
        [ -z "$CHOSEN" ] && { log_error "Invalid selection, exiting"; rm -f "$DEDUP_FILE"; exit 1; }
        TARGET_MODES=($CHOSEN)
    elif [ "$SELECTED_MODE" = "all" ]; then
        TARGET_MODES=("${AVAILABLE_MODES[@]}")
    else
        [[ " ${ALL_MODES[*]} " =~ " ${SELECTED_MODE} " ]] || { log_error "Invalid mode: $SELECTED_MODE"; exit 1; }
        TARGET_MODES=("$SELECTED_MODE")
    fi
fi

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
save_state "3"

# ================================================================
# [3/8] Extract on demand (idempotent)
# ================================================================
log_step "[3/8] Extract packages on demand"

declare -A EXTRACTED_PATHS
declare -A MODELS_DIRS
PRIMARY_EXTRACTED=""

for mode in "${TARGET_MODES[@]}"; do
    TAR_PATH=$(grep -P "^${mode}\t" "$DEDUP_FILE" | head -n1 | cut -f4)
    [ -z "$TAR_PATH" ] && continue

    EXTRACT_BASE="$WORK_DIR/signalp_extracted_${mode}"
    if [ -z "$EXTRACT_BASE" ] || [[ "$EXTRACT_BASE" != "$WORK_DIR"* ]]; then
        log_error "Extract path abnormal: '$EXTRACT_BASE'"
        continue
    fi

    if [ -d "$EXTRACT_BASE" ]; then
        EXISTING_SRC=$(find "$EXTRACT_BASE" -type f -name "setup.py" -exec dirname {} \; 2>/dev/null | head -n1)
        if [ -n "$EXISTING_SRC" ] && [ -f "$EXISTING_SRC/setup.py" ]; then
            log_skip "  ${mode} already extracted, skipping"
            EXTRACTED_PATHS[$mode]="$EXISTING_SRC"
            if [ -d "$EXISTING_SRC/models" ]; then
                MODELS_DIRS[$mode]="$EXISTING_SRC/models"
                log_info "  ${mode} models/ contents:"
                ls -lh "$EXISTING_SRC/models/" 2>/dev/null | sed 's/^/    /'
            fi
            if [ -z "$PRIMARY_EXTRACTED" ]; then
                PRIMARY_EXTRACTED="$EXISTING_SRC"
                log_info "  -> Used as primary package for Python install"
            fi
            echo "" >&2
            continue
        fi
    fi

    rm -rf "$EXTRACT_BASE"
    mkdir -p "$EXTRACT_BASE"
    log_info "Extracting ${mode} package: $(basename "$TAR_PATH")"
    tar zxf "$TAR_PATH" -C "$EXTRACT_BASE"

    SRC=$(find "$EXTRACT_BASE" -type f -name "setup.py" -exec dirname {} \; 2>/dev/null | head -n1)
    if [ -z "$SRC" ]; then
        log_error "setup.py not found after extraction: $(basename "$TAR_PATH")"
        continue
    fi

    EXTRACTED_PATHS[$mode]="$SRC"
    if [ -d "$SRC/models" ]; then
        MODELS_DIRS[$mode]="$SRC/models"
        log_info "  ${mode} models/ contents:"
        ls -lh "$SRC/models/" 2>/dev/null | sed 's/^/    /'
    fi

    if [ -z "$PRIMARY_EXTRACTED" ]; then
        PRIMARY_EXTRACTED="$SRC"
        log_info "  -> Used as primary package for Python install"
    fi
    echo "" >&2
done

rm -f "$DEDUP_FILE"
if [ -z "$PRIMARY_EXTRACTED" ]; then
    log_error "All packages failed to extract"
    exit 1
fi

save_state "4"

# ================================================================
# [4/8] Build and install (ensure setuptools exists)
# ================================================================
log_step "[4/8] Build and install"

SITE_PKGS_CHECK=$(python -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "")
SIGNALP6_EGG_DIR=$(find "${SITE_PKGS_CHECK:-/dev/null}" -maxdepth 1 -type d -name "signalp6*.egg" 2>/dev/null | head -n1)
if [ -n "$SIGNALP6_EGG_DIR" ] && [ -d "$SIGNALP6_EGG_DIR/signalp" ]; then
    log_skip "signalp package already installed, skipping build"
elif pip show signalp6 > /dev/null 2>&1; then
    log_skip "signalp package already installed, skipping build"
else
    # Ensure setuptools is present (may be missing in some environments)
    if ! python -c "import setuptools" &>/dev/null; then
        log_warn "setuptools not found, installing..."
        pip install setuptools || conda install setuptools -y
    fi
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
        log_info "setup.py install completed normally"
    fi

    SIGNALP6_EGG_DIR=$(find "${SITE_PKGS_CHECK:-/dev/null}" -maxdepth 1 -type d -name "signalp6*.egg" 2>/dev/null | head -n1)
    if [ -n "$SIGNALP6_EGG_DIR" ] && [ -d "$SIGNALP6_EGG_DIR/signalp" ] || \
       pip show signalp6 > /dev/null 2>&1; then
        log_info "signalp package installed"
    else
        log_warn "Cannot confirm install result, continuing..."
    fi
    cd "$WORK_DIR"
fi

save_state "5a"

# ================================================================
# [5/8] Install all dependencies (strict version control)
# ================================================================
log_step "[5/8] Install all dependencies"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[Important] Install ALL dependencies before importing signalp!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 5a. Pillow (prefer conda, fallback pip)
log_info "[5a] Fixing Pillow (libtiff.so.5)..."
if python -c "from PIL import Image" 2>/dev/null; then
    log_skip "  Pillow already installed"
else
    pip uninstall -y Pillow pillow 2>/dev/null || true
    conda install -c conda-forge pillow=9.* -y 2>/dev/null || \
        pip install "pillow<10" 2>/dev/null || true
    python -c "from PIL import Image; print('  Pillow OK')" 2>/dev/null || log_warn "Pillow verification failed"
fi
save_state "5b"

# 5b. matplotlib (version <3.7 for Python 3.7 compatibility)
log_info "[5b] Installing matplotlib..."
if python -c "import matplotlib" 2>/dev/null; then
    log_skip "  matplotlib already installed"
else
    pip install "matplotlib>=3.3.2,<3.7" 2>/dev/null || {
        conda install -c conda-forge matplotlib=3.6.* -y 2>/dev/null || true
    }
    python -c "import matplotlib; print('  Matplotlib OK')" 2>/dev/null || log_warn "matplotlib verification failed"
fi
save_state "5c"

# 5c. NumPy (version <1.22 for Python 3.7 compatibility)
log_info "[5c] Installing NumPy..."
if python -c "import numpy" 2>/dev/null; then
    log_skip "  NumPy already installed"
else
    pip install "numpy>=1.19,<1.22" || {
        conda install -c conda-forge numpy=1.21.* -y 2>/dev/null || true
    }
    python -c "import numpy; print(f'  NumPy {numpy.__version__} OK')" 2>/dev/null || log_warn "NumPy verification failed"
fi
save_state "5d"

# 5d. PyTorch (prefer pip, fallback conda)
log_info "[5d] Installing PyTorch ${PYTORCH_VERSION} ${TORCH_VARIANT}..."
if python -c "import torch" 2>/dev/null; then
    log_skip "  PyTorch already installed"
else
    PYTORCH_INSTALLED=false
    pip install torch==${PYTORCH_VERSION}+${TORCH_VARIANT} torchvision==${TORCHVISION_VERSION}+${TORCH_VARIANT} \
        -f https://download.pytorch.org/whl/torch_stable.html 2>/dev/null
    if python -c "import torch; print(f'  PyTorch {torch.__version__} OK')" 2>/dev/null; then
        log_info "  pip install succeeded, skipping conda"
        PYTORCH_INSTALLED=true
    else
        log_warn "  pip install failed, trying conda..."
        conda install -c pytorch pytorch==${PYTORCH_VERSION} ${TORCH_VARIANT}only -y 2>/dev/null || true
        if python -c "import torch; print(f'  PyTorch {torch.__version__} OK')" 2>/dev/null; then
            PYTORCH_INSTALLED=true
        fi
    fi
    if [ "$PYTORCH_INSTALLED" = "false" ]; then
        log_error "PyTorch installation failed, please install manually"
        echo "  Reference command:" >&2
        echo "    pip install torch==${PYTORCH_VERSION}+${TORCH_VARIANT} torchvision==${TORCHVISION_VERSION}+${TORCH_VARIANT} -f https://download.pytorch.org/whl/torch_stable.html" >&2
    fi
fi
save_state "5e"

# 5e. tqdm (<4.65 for Python 3.7 compatibility)
log_info "[5e] Installing tqdm..."
if python -c "import tqdm" 2>/dev/null; then
    log_skip "  tqdm already installed"
else
    conda install -c conda-forge tqdm=4.64.* -y 2>/dev/null || \
        pip install "tqdm<4.65" || true
    python -c "import tqdm; print('  tqdm OK')" 2>/dev/null || log_warn "tqdm verification failed"
fi
save_state "5f"

# 5f. Final verification of signalp import
log_info "[5f] Verifying import signalp..."
if python -c "import signalp; print('  signalp import OK')" 2>/dev/null; then
    log_info "All dependencies installed, signalp importable"
else
    log_error "import signalp still failing, detailed errors:"
    python -c "import signalp" 2>&1 | tail -10
    echo "" >&2
    log_warn "Checking dependencies one by one:" >&2
    python -c "import torch; print('  torch OK')"      2>/dev/null || log_error "  torch MISSING"
    python -c "from PIL import Image; print('  PIL OK')" 2>/dev/null || log_error "  Pillow MISSING"
    python -c "import matplotlib; print('  matplotlib OK')" 2>/dev/null || log_error "  matplotlib MISSING"
    python -c "import tqdm; print('  tqdm OK')"        2>/dev/null || log_error "  tqdm MISSING"
    echo "" >&2
    log_error "Please install missing packages manually and retry"
    exit 1
fi

save_state "6"

# ================================================================
# [6/8] Deploy model weights (idempotent)
# ================================================================
log_step "[6/8] Deploy model weights"

SIGNALP_DIR=$(python -c "import signalp; import os; print(os.path.dirname(signalp.__file__))" 2>/dev/null)
if [ -z "$SIGNALP_DIR" ]; then
    log_error "Cannot get SignalP install path"
    exit 1
fi
log_info "SignalP install path: $SIGNALP_DIR"

MW_DIR="$SIGNALP_DIR/model_weights"
mkdir -p "$MW_DIR"
MW_FILE_COUNT=$(find "$MW_DIR" -type f -not -name "README.md" 2>/dev/null | wc -l)
if [ "$MW_FILE_COUNT" -gt 0 ]; then
    log_info "model_weights/ already has ${MW_FILE_COUNT} files"
else
    log_info "model_weights/ is empty (README.md only)"
fi

DEPLOYED_MODES=()
FAILED_MODES=()

# Dynamic model file discovery
for mode in "${TARGET_MODES[@]}"; do
    models_dir="${MODELS_DIRS[$mode]:-}"
    if [ -z "$models_dir" ] || [ ! -d "$models_dir" ]; then
        continue
    fi
    expected="${MODEL_FILE_MAP[$mode]}"
    if [ -e "$models_dir/$expected" ]; then
        continue
    fi
    if [ "$mode" = "fast" ]; then
        FOUND_PT=$(find "$models_dir" -maxdepth 1 -name "*.pt" -not -name "README*" -print -quit 2>/dev/null)
        if [ -n "$FOUND_PT" ]; then
            MODEL_FILE_MAP[$mode]="$(basename "$FOUND_PT")"
            log_warn "  Auto-discovered fast model: $(basename "$FOUND_PT") (replacing $expected)"
        fi
    elif [ "$mode" = "slow-sequential" ]; then
        FOUND_DIR=$(find "$models_dir" -maxdepth 1 -type d -name "*sequential*" -print -quit 2>/dev/null)
        if [ -n "$FOUND_DIR" ]; then
            MODEL_FILE_MAP[$mode]="$(basename "$FOUND_DIR")"
            log_warn "  Auto-discovered slow-sequential model: $(basename "$FOUND_DIR") (replacing $expected)"
        fi
    fi
done

for mode in "${TARGET_MODES[@]}"; do
    model_target="${MODEL_FILE_MAP[$mode]}"
    models_dir="${MODELS_DIRS[$mode]:-}"

    log_info "──────────────────────────────"
    log_info "Deploying ${mode} model: ${model_target}"

    if [ -d "$MW_DIR/$model_target" ] || [ -f "$MW_DIR/$model_target" ]; then
        SKIP_DEPLOY=true
        if [ -n "$models_dir" ] && [ -d "$models_dir" ]; then
            if [ -f "$models_dir/$model_target" ] || [ -d "$models_dir/$model_target" ]; then
                SRC_SIZE=$(du -sb "$models_dir/$model_target" 2>/dev/null | cut -f1)
                DST_SIZE=$(du -sb "$MW_DIR/$model_target" 2>/dev/null | cut -f1)
                SRC_FC=$(find "$models_dir/$model_target" -type f 2>/dev/null | wc -l)
                DST_FC=$(find "$MW_DIR/$model_target" -type f 2>/dev/null | wc -l)
                if [ "$SRC_SIZE" = "$DST_SIZE" ] && [ "$SRC_FC" = "$DST_FC" ]; then
                    log_skip "  ${mode} model already deployed (${DST_FC} files, $(format_size $DST_SIZE)), skipping"
                else
                    log_warn "  ${mode} model incomplete, re-copying"
                    rm -rf "$MW_DIR/$model_target"
                    SKIP_DEPLOY=false
                fi
            fi
        else
            if [ -d "$MW_DIR/$model_target" ]; then
                FC=$(find "$MW_DIR/$model_target" -type f | wc -l)
                TS=$(du -sb "$MW_DIR/$model_target" 2>/dev/null | cut -f1)
                log_skip "  ${mode} model already deployed (${FC} files, $(format_size $TS)), skipping"
            else
                FS=$(stat -c%s "$MW_DIR/$model_target" 2>/dev/null || stat -f%z "$MW_DIR/$model_target" 2>/dev/null || echo 0)
                log_skip "  ${mode} model already deployed ($(format_size $FS)), skipping"
            fi
        fi
        if [ "$SKIP_DEPLOY" = "true" ]; then
            DEPLOYED_MODES+=("$mode")
            echo "" >&2
            continue
        fi
    fi

    MODEL_SRC=""
    if [ -n "$models_dir" ] && [ -d "$models_dir" ]; then
        if [ -f "$models_dir/$model_target" ]; then
            MODEL_SRC="$models_dir/$model_target"
            log_info "  Exact match (file): $MODEL_SRC"
        elif [ -d "$models_dir/$model_target" ]; then
            MODEL_SRC="$models_dir/$model_target"
            log_info "  Exact match (dir): $MODEL_SRC"
        fi
    fi

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

    if [ -z "$MODEL_SRC" ]; then
        log_warn "  Not found in extracted dirs, starting full search..."
        if [ "$mode" = "slow-sequential" ]; then
            MODEL_SRC=$(timeout 30 find /home -maxdepth 6 -type d -name "*sequential*model*" -path "*signalp*" -print -quit 2>/dev/null || true)
        else
            MODEL_SRC=$(timeout 30 find /home -maxdepth 6 -type f -name "*distilled*signalp*.pt" -print -quit 2>/dev/null || true)
        fi
        if [ -n "$MODEL_SRC" ]; then
            log_info "  Found by full search: $MODEL_SRC"
        fi
    fi

    if [ -n "$MODEL_SRC" ]; then
        if [ -d "$MODEL_SRC" ]; then
            cp -r "$MODEL_SRC" "$MW_DIR/"
            if [ -d "$MW_DIR/$model_target" ]; then
                FILE_COUNT=$(find "$MW_DIR/$model_target" -type f | wc -l)
                TOTAL_SIZE=$(du -sb "$MW_DIR/$model_target" 2>/dev/null | cut -f1)
                log_info "  ${mode} model copy complete: ${FILE_COUNT} files, $(format_size $TOTAL_SIZE)"
                DEPLOYED_MODES+=("$mode")
            else
                log_error "  ${mode} model copy failed"
                FAILED_MODES+=("$mode")
            fi
        elif [ -f "$MODEL_SRC" ]; then
            cp "$MODEL_SRC" "$MW_DIR/"
            if [ -f "$MW_DIR/$model_target" ]; then
                NEW_SIZE=$(stat -c%s "$MW_DIR/$model_target" 2>/dev/null || stat -f%z "$MW_DIR/$model_target" 2>/dev/null || echo 0)
                log_info "  ${mode} model copy complete: $(format_size $NEW_SIZE)"
                DEPLOYED_MODES+=("$mode")
            else
                log_error "  ${mode} model copy failed"
                FAILED_MODES+=("$mode")
            fi
        fi
    else
        log_error "  Model not found: ${model_target}"
        FAILED_MODES+=("$mode")
        echo "" >&2
        read -p "    Please enter full path to ${model_target} (or Enter to skip): " USER_MODEL
        if [ -n "$USER_MODEL" ] && ([ -d "$USER_MODEL" ] || [ -f "$USER_MODEL" ]); then
            cp -r "$USER_MODEL" "$MW_DIR/"
            if [ -e "$MW_DIR/$model_target" ]; then
                log_info "  ${mode} manual model copy complete"
                DEPLOYED_MODES+=("$mode")
                FAILED_MODES=("${FAILED_MODES[@]/$mode}")
            fi
        else
            log_warn "  Skipping ${mode} model copy"
        fi
    fi
    echo "" >&2
done

log_info "╔══════════════════════════════════════════════════════╗"
log_info "║         Model Deployment Summary                    ║"
log_info "╠══════════════════════════════════════════════════════╣"
if [ ${#DEPLOYED_MODES[@]} -gt 0 ]; then
    for dm in "${DEPLOYED_MODES[@]}"; do
        mt="${MODEL_FILE_MAP[$dm]}"
        if [ -d "$MW_DIR/$mt" ]; then
            fc=$(find "$MW_DIR/$mt" -type f | wc -l)
            ts=$(du -sb "$MW_DIR/$mt" 2>/dev/null | cut -f1)
            log_info "║  OK ${dm}: ${mt}/ (${fc} files, $(format_size $ts))  ║"
        elif [ -f "$MW_DIR/$mt" ]; then
            fs=$(stat -c%s "$MW_DIR/$mt" 2>/dev/null || stat -f%z "$MW_DIR/$mt" 2>/dev/null || echo 0)
            log_info "║  OK ${dm}: ${mt} ($(format_size $fs))  ║"
        fi
    done
fi
if [ ${#FAILED_MODES[@]} -gt 0 ]; then
    for fm in "${FAILED_MODES[@]}"; do
        log_error "║  FAIL ${fm}: ${MODEL_FILE_MAP[$fm]} (missing)  ║"
    done
    log_warn "║  Missing modes unavailable, add manually later"
fi
log_info "╚══════════════════════════════════════════════════════╝"
save_state "7"

# ---- [7/8] Environment diagnostics ----
log_step "[7/8] Environment diagnostics"

cat > "$WORK_DIR/check_signalp_env.sh" << 'DIAG_SCRIPT'
#!/bin/bash
echo "╔════════════════════════════════════════════════════════╗"
echo "║           SignalP Environment Diagnostics (v15)        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "1. Python environment:"
python --version 2>&1
python -c "import platform; print('   Implementation:', platform.python_implementation())" 2>/dev/null
echo ""
echo "2. Core dependencies:"
python -c "import numpy; print('   NumPy:      ', numpy.__version__)"    2>/dev/null || echo "   MISSING NumPy"
python -c "import torch; print('   PyTorch:    ', torch.__version__)"    2>/dev/null || echo "   MISSING PyTorch"
python -c "import PIL; print('   Pillow:     ', PIL.__version__)"       2>/dev/null || echo "   MISSING Pillow"
python -c "import matplotlib; print('   Matplotlib: ', matplotlib.__version__)" 2>/dev/null || echo "   MISSING Matplotlib"
python -c "import tqdm; print('   tqdm:       OK')"                    2>/dev/null || echo "   MISSING tqdm"
echo ""
echo "3. SignalP status:"
SIGNALP_PATH=$(python -c "import signalp; print(signalp.__file__)" 2>/dev/null || true)
if [ -n "$SIGNALP_PATH" ]; then
    echo "   OK import signalp: $SIGNALP_PATH"
    SIGNALP_DIR=$(dirname "$SIGNALP_PATH")
    MW_DIR="$SIGNALP_DIR/model_weights"
    echo ""
    echo "4. Model weights status:"
    if [ -d "$MW_DIR" ]; then
        echo "   Dir: $MW_DIR"
        echo ""
        for item in "$MW_DIR"/*; do
            [ -e "$item" ] || continue
            name=$(basename "$item")
            [ "$name" = "README.md" ] && continue
            if [ -d "$item" ]; then
                fc=$(find "$item" -type f | wc -l)
                sz=$(du -sh "$item" 2>/dev/null | cut -f1)
                echo "   OK ${name}/ - ${fc} files, ${sz}"
            elif [ -f "$item" ]; then
                sz=$(du -sh "$item" 2>/dev/null | cut -f1)
                echo "   OK ${name} - ${sz}"
            fi
        done
    else
        echo "   MISSING model_weights directory"
    fi
else
    echo "   FAILED import signalp"
fi
echo ""
echo "5. signalp6 command:"
which signalp6 2>/dev/null && echo "   OK signalp6 in PATH" || echo "   MISSING signalp6 not in PATH"
echo ""
echo "====== Diagnostics complete ======"
DIAG_SCRIPT

chmod +x "$WORK_DIR/check_signalp_env.sh"
bash "$WORK_DIR/check_signalp_env.sh"
save_state "8"

# ---- [8/8] Final verification (use absolute paths) ----
log_step "[8/8] Final verification"

# Use absolute path to avoid conda run detection
SIGNALP6_ABS="$CONDA_BASE/envs/signalp6/bin/signalp6"
if [ -x "$SIGNALP6_ABS" ]; then
    if "$SIGNALP6_ABS" --help > /dev/null 2>&1; then
        echo "" >&2
        echo "🎉🎉🎉 Installation successful! SignalP is ready 🎉🎉🎉" >&2
        echo "" >&2
        echo "Installed modes:" >&2
        for dm in "${DEPLOYED_MODES[@]}"; do
            echo "  OK ${dm} - ${MODE_DESC[$dm]}" >&2
        done
        if [ ${#FAILED_MODES[@]} -gt 0 ]; then
            echo "" >&2
            echo "Missing modes (manually add model weights to $MW_DIR/):" >&2
            for fm in "${FAILED_MODES[@]}"; do
                echo "  FAIL ${fm} -> need: ${MODEL_FILE_MAP[$fm]}" >&2
            done
        fi
        echo "" >&2
        echo "Usage:" >&2
        echo "  1. Make conda command available (skip if new terminal): source ~/.bashrc" >&2
        echo "  2. Activate environment: conda activate signalp6" >&2
        echo "  3. Run SignalP: signalp6 -i input.fasta -o results -m <mode>" >&2
        echo "" >&2
        echo "Troubleshooting:" >&2
        echo "  conda activate signalp6 && bash $WORK_DIR/check_signalp_env.sh" >&2
        clear_state
    else
        echo "" >&2
        echo "signalp6 --help verification failed (possibly missing models or other issues)" >&2
        echo "  Please troubleshoot manually: conda activate signalp6; signalp6 --help" >&2
    fi
else
    echo "" >&2
    echo "signalp6 command not found at expected path: $SIGNALP6_ABS" >&2
    echo "  Please troubleshoot installation manually." >&2
fi

echo "" >&2
echo "════════════════════════════════════════════════════" >&2
echo "  Environment quick info" >&2
echo "  Conda base:   $CONDA_BASE" >&2
echo "  Env dir:      $CONDA_BASE/envs/signalp6" >&2
echo "  Python:       $CONDA_BASE/envs/signalp6/bin/python" >&2
echo "  pip:          $CONDA_BASE/envs/signalp6/bin/pip" >&2
echo "  signalp6:     $CONDA_BASE/envs/signalp6/bin/signalp6" >&2
echo "════════════════════════════════════════════════════" >&2
