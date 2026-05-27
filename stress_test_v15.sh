#!/bin/bash
# ============================================================
# SignalP 6.0 v15 暴力测试套件 / Stress Test Suite
# ============================================================
#
# 覆盖场景 / Coverage:
#   T01  全新安装 fast 模式（基线）
#   T02  --reset 强制重装
#   T03  已安装状态重跑（幂等性 / idempotency）
#   T04  Step 3 解压中断 → 续装
#   T05  Step 5d PyTorch 下载中断 → 续装 (Bug #7 specific)
#   T06  Step 6 模型复制中断 → 续装（完整性校验 / integrity check）
#   T07  连续两次中断（Step 5a + Step 6）→ 续装
#   T08  中断后续装菜单选择"重新安装"
#   T09  -h 帮助参数
#   T10  全新安装 all 模式（最终综合测试）
#
# 用法 / Usage:
#   bash stress_test_v15.sh                      # 运行全部 fast 测试
#   bash stress_test_v15.sh --all                 # 含 slow-sequential + all
#   bash stress_test_v15.sh --list                # 仅列出测试项
#   bash stress_test_v15.sh --test 5              # 仅运行 T05
#   bash stress_test_v15.sh --test 4,5,6          # 运行 T04 T05 T06
#
# 前提 / Prerequisites:
#   - Miniconda/Anaconda 已安装并初始化
#   - signalp-6.0h.fast.tar.gz 在桌面或脚本同目录
#   - 网络可用（conda + pip 需要下载依赖）
#
# ============================================================

set -uo pipefail

# ---- Configuration ----
INSTALLER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/install_signalp6_v15.sh"
[ ! -f "$INSTALLER" ] && { echo "ERROR: 安装脚本不存在: $INSTALLER"; exit 1; }

WORK_DIR="$(cd "$(dirname "$INSTALLER")" 2>/dev/null && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$WORK_DIR/stress_test_${TIMESTAMP}"
RESULTS_FILE="$LOG_DIR/results.txt"
STATE_FILE="$HOME/.signalp6_install_state"

PASS=0; FAIL=0; SKIP=0; TOTAL=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

mkdir -p "$LOG_DIR"

# ================================================================
#  Helper Functions
# ================================================================

log_pass() { echo -e "  ${GREEN}✅ PASS${NC}  $1"; PASS=$((PASS+1)); }
log_fail() { echo -e "  ${RED}❌ FAIL${NC}  $1"; FAIL=$((FAIL+1)); }
log_skip() { echo -e "  ${YELLOW}⏭ SKIP${NC}  $1"; SKIP=$((SKIP+1)); }
log_info() { echo -e "  ${CYAN}ℹ${NC}  $1"; }
log_step() { echo -e "\n${BOLD}━━━ $1 ━━━${NC}"; }

cleanup() {
    log_info "Cleaning environment..."
    # Remove conda env
    if eval "$(conda shell.bash hook 2>/dev/null)" && \
       conda env list 2>/dev/null | grep -q "^signalp6 "; then
        conda remove -n signalp6 --all -y >/dev/null 2>&1 || true
    fi
    # Clear conda lock files (kill -9 from previous tests may leave stale locks)
    eval "$(conda shell.bash hook 2>/dev/null)" 2>/dev/null
    conda clean --lock >/dev/null 2>&1 || true
    # Clear state
    rm -f "$STATE_FILE"
    # Remove extracted dirs
    rm -rf "$WORK_DIR"/signalp_extracted_*
    # Temp files
    rm -f /tmp/signalp_install.log
    log_info "Clean done"
}

verify_installation() {
    local errors=0
    local vlog="$LOG_DIR/verify_$$.log"
    eval "$(conda shell.bash hook 2>/dev/null)"

    # 1. signalp6 command
    if conda run -n signalp6 signalp6 -h >"$vlog" 2>&1; then
        log_info "signalp6 command OK"
    else
        log_info "signalp6 command FAILED"; errors=$((errors+1))
    fi

    # 2. import signalp
    if conda run -n signalp6 python -c "import signalp; print('OK')" >>"$vlog" 2>&1; then
        log_info "import signalp OK"
    else
        log_info "import signalp FAILED"; errors=$((errors+1))
    fi

    # 3. PyTorch
    if conda run -n signalp6 python -c "import torch; print(f'torch {torch.__version__}')" >>"$vlog" 2>&1; then
        log_info "PyTorch OK"
    else
        log_info "PyTorch FAILED"; errors=$((errors+1))
    fi

    # 4. Model files
    local model_info=$(conda run -n signalp6 python -c "
import signalp, os
d = os.path.dirname(signalp.__file__)
mw = os.path.join(d, 'model_weights')
if os.path.isdir(mw):
    items = [i for i in os.listdir(mw) if i != 'README.md']
    print(f'{len(items)}|{items}')
else:
    print('0|NO_MODEL_WEIGHTS')
" 2>>"$vlog")
    local mc=$(echo "$model_info" | cut -d'|' -f1)
    local mi=$(echo "$model_info" | cut -d'|' -f2-)
    if [ "$mc" -gt 0 ]; then
        log_info "Models: $mc item(s) - $mi"
    else
        log_info "Models MISSING: $mi"; errors=$((errors+1))
    fi

    rm -f "$vlog"
    return $errors
}

# Start installer in background, wait for a pattern, then SIGINT
interrupt_at_pattern() {
    local pattern="$1"
    local mode="$2"
    local max_wait="${3:-300}"
    local log="$4"

    > "$log"
    bash "$INSTALLER" -m "$mode" > "$log" 2>&1 &
    local pid=$!

    log_info "Started PID=$pid, waiting for: $pattern (timeout ${max_wait}s)"

    local waited=0
    local found=false
    while [ $waited -lt $max_wait ]; do
        if ! kill -0 $pid 2>/dev/null; then
            wait $pid 2>/dev/null
            local exit_rc=$?
            log_info "Process exited before reaching target (after ${waited}s, exit=$exit_rc)"
            log_info "--- Last 30 lines of installer log ---"
            tail -30 "$log" 2>/dev/null | sed 's/^/    /'
            log_info "--- End ---"
            return 2
        fi
        if grep -q "$pattern" "$log" 2>/dev/null; then
            sleep 3   # Let the step execute a bit before killing
            log_info "Pattern detected -> sending SIGINT"
            kill -INT $pid 2>/dev/null
            sleep 3
            kill -9 $pid 2>/dev/null 2>/dev/null
            wait $pid 2>/dev/null
            found=true
            break
        fi
        sleep 2
        waited=$((waited + 2))
        printf "  ... waiting (%ds/%ds)\r" "$waited" "$max_wait" >&2
    done
    echo "" >&2

    if ! $found; then
        log_info "TIMEOUT (${max_wait}s) - pattern not found"
        log_info "--- Last 30 lines of installer log ---"
        tail -30 "$log" 2>/dev/null | sed 's/^/    /'
        log_info "--- End ---"
        kill -9 $pid 2>/dev/null
        wait $pid 2>/dev/null
        return 1
    fi

    # Report state
    if [ -f "$STATE_FILE" ]; then
        local step=$(grep '^CURRENT_STEP=' "$STATE_FILE" | sed 's/^CURRENT_STEP=//' | tr -d '"')
        local modes=$(grep '^TARGET_MODES=' "$STATE_FILE" | sed 's/^TARGET_MODES=//' | tr -d '"')
        log_info "State saved: step=$step, modes=$modes"
    else
        log_info "WARNING: No state file!"
    fi
    return 0
}

# Resume installer with given menu choice
run_resume() {
    local choice="$1"   # 1=continue, 2=fresh install
    local mode="${2:-}"  # optional: -m mode
    local log="$LOG_DIR/resume_$$_$(date +%N).log"

    log_info "Resuming (menu choice=$choice)..."
    if [ -n "$mode" ]; then
        echo "$choice" | bash "$INSTALLER" -m "$mode" > "$log" 2>&1
    else
        echo "$choice" | bash "$INSTALLER" > "$log" 2>&1
    fi
    local rc=$?
    log_info "Resume exit code: $rc"

    if grep -q "安装成功\|Installation successful" "$log" 2>/dev/null; then
        log_info "Success message detected"
    else
        log_info "WARNING: No success message"
        # Show last 20 lines for debugging
        log_info "--- Last 20 lines of resume log ---"
        tail -20 "$log" | sed 's/^/    /'
        log_info "--- End ---"
    fi

    echo "$log"
    return $rc
}

# Wrapper for each test
run_test() {
    local name="$1"
    local desc="$2"
    shift 2

    TOTAL=$((TOTAL+1))
    local tlog="$LOG_DIR/T$(printf '%02d' $TOTAL)_${name}.log"
    local start=$(date +%s)

    echo ""
    log_step "T$(printf '%02d' $TOTAL): $name — $desc"

    # Run test function, capture output
    if "$@" > "$tlog" 2>&1; then
        local elapsed=$(( $(date +%s) - start ))
        log_pass "$name (${elapsed}s)"
        echo "PASS|T$(printf '%02d' $TOTAL)|$name|$elapsed" >> "$RESULTS_FILE"
    else
        local elapsed=$(( $(date +%s) - start ))
        log_fail "$name (${elapsed}s) -> log: $tlog"
        echo "FAIL|T$(printf '%02d' $TOTAL)|$name|$elapsed" >> "$RESULTS_FILE"
    fi
}

# ================================================================
#  Test Cases
# ================================================================

# T01: Clean install - fast mode
t_clean_fast() {
    cleanup
    bash "$INSTALLER" -m fast
    verify_installation
}

# T02: --reset on existing installation
t_reset_flag() {
    cleanup
    log_info "First install (fast)..."
    bash "$INSTALLER" -m fast >/dev/null 2>&1
    verify_installation || { log_info "First install failed!"; return 1; }

    log_info "Running with --reset..."
    bash "$INSTALLER" --reset -m fast
    verify_installation
}

# T03: Re-run on already installed (idempotency check)
t_skip_installed() {
    cleanup
    log_info "Initial install..."
    bash "$INSTALLER" -m fast >/dev/null 2>&1

    log_info "Re-running on installed state..."
    local log="$LOG_DIR/skip_test_$$.log"
    bash "$INSTALLER" -m fast > "$log" 2>&1

    local skip_count=$(grep -c '\[SKIP\]' "$log" 2>/dev/null || echo 0)
    log_info "SKIP messages: $skip_count"
    if [ "$skip_count" -ge 3 ]; then
        log_info "Idempotency verified (>= 3 skips)"
        return 0
    else
        log_info "Insufficient skips (expected >= 3, got $skip_count)"
        return 1
    fi
}

# T04: Interrupt at Step 3 (extraction) -> resume
t_interrupt_step3() {
    cleanup
    local log="$LOG_DIR/int3_$$.log"
    interrupt_at_pattern "\[3/8\].*Extract" "fast" 120 "$log"
    local rc=$?
    [ $rc -ne 0 ] && { log_info "Interrupt failed (rc=$rc)"; return 1; }

    run_resume 1 "fast"
    verify_installation
}

# T05: Interrupt at Step 5d (PyTorch download) -> resume (Bug #7 specific)
t_interrupt_step5d() {
    cleanup
    local log="$LOG_DIR/int5d_$$.log"
    interrupt_at_pattern "\[5d\].*PyTorch" "fast" 600 "$log"
    local rc=$?
    [ $rc -ne 0 ] && { log_info "Interrupt failed (rc=$rc)"; return 1; }

    log_info "=== Bug #7 verification: set +e should allow conda fallback ==="
    local rlog=$(run_resume 1 "fast")

    # Check that the resume completed successfully despite potential PyTorch pip failure
    if grep -q "安装成功\|Installation successful" "$rlog" 2>/dev/null; then
        log_info "Bug #7: set +e working correctly"
    fi

    verify_installation
}

# T06: Interrupt at Step 6 (model copy) -> resume with integrity check
t_interrupt_step6() {
    cleanup
    local log="$LOG_DIR/int6_$$.log"
    interrupt_at_pattern "\[6/8\].*model" "fast" 600 "$log"
    local rc=$?
    [ $rc -ne 0 ] && { log_info "Interrupt failed (rc=$rc)"; return 1; }

    local rlog=$(run_resume 1 "fast")

    # Check if integrity check triggered re-copy
    if grep -qi "不完整\|incomplete\|重新复制\|re-copy" "$rlog" 2>/dev/null; then
        log_info "Integrity check triggered (re-copy detected)"
    else
        log_info "Note: integrity check may have skipped (model already complete)"
    fi

    verify_installation
}

# T07: Double interrupt (Step 5a then Step 6) -> resume
t_double_interrupt() {
    cleanup

    # First interrupt at Step 5a
    log_info "--- First interrupt: Step 5a (Pillow) ---"
    local log1="$LOG_DIR/dbl1_$$.log"
    interrupt_at_pattern "\[5a\].*Pillow" "fast" 600 "$log1"
    [ $? -ne 0 ] && { log_info "First interrupt failed"; return 1; }

    # Resume but interrupt again at Step 6
    log_info "--- Second interrupt: Step 6 (model copy) ---"
    local log2="$LOG_DIR/dbl2_$$.log"
    > "$log2"
    echo "1" | bash "$INSTALLER" -m fast > "$log2" 2>&1 &
    local pid=$!
    log_info "Resume PID=$pid"

    local waited=0
    while [ $waited -lt 600 ]; do
        if ! kill -0 $pid 2>/dev/null; then
            wait $pid 2>/dev/null
            break
        fi
        if grep -q "\[6/8\]" "$log2" 2>/dev/null; then
            sleep 3
            log_info "Step 6 detected -> second SIGINT"
            kill -INT $pid 2>/dev/null
            sleep 3
            kill -9 $pid 2>/dev/null
            wait $pid 2>/dev/null
            break
        fi
        sleep 2
        waited=$((waited + 2))
    done

    # Final resume
    log_info "--- Final resume ---"
    run_resume 1 "fast"
    verify_installation
}

# T08: Interrupt -> resume menu choose "fresh install" (option 2)
t_resume_fresh() {
    cleanup
    local log="$LOG_DIR/fresh_$$.log"
    interrupt_at_pattern "\[3/8\].*Extract" "fast" 120 "$log"
    [ $? -ne 0 ] && { log_info "Interrupt failed"; return 1; }

    log_info "Choosing 'fresh install' from resume menu..."
    run_resume 2 "fast"
    verify_installation
}

# T09: Help flag
t_help_flag() {
    local log="$LOG_DIR/help_$$.log"
    bash "$INSTALLER" -h > "$log" 2>&1
    if grep -qi "usage\|用法" "$log" 2>/dev/null; then
        log_info "Help output OK"
        return 0
    else
        log_info "Help output missing!"
        return 1
    fi
}

# T10: Clean install - all modes (comprehensive)
t_clean_all() {
    cleanup
    bash "$INSTALLER" -m all
    verify_installation
}

# ================================================================
#  Test Registry
# ================================================================

declare -A TEST_FUNCS=(
    ["01"]="t_clean_fast"
    ["02"]="t_reset_flag"
    ["03"]="t_skip_installed"
    ["04"]="t_interrupt_step3"
    ["05"]="t_interrupt_step5d"
    ["06"]="t_interrupt_step6"
    ["07"]="t_double_interrupt"
    ["08"]="t_resume_fresh"
    ["09"]="t_help_flag"
    ["10"]="t_clean_all"
)

declare -A TEST_DESCS=(
    ["01"]="Clean install fast (baseline)"
    ["02"]="--reset on existing install"
    ["03"]="Re-run idempotency (SKIP check)"
    ["04"]="Interrupt Step 3 (extraction) -> resume"
    ["05"]="Interrupt Step 5d (PyTorch) -> resume [Bug#7]"
    ["06"]="Interrupt Step 6 (model copy) -> resume [integrity]"
    ["07"]="Double interrupt (5a + 6) -> resume"
    ["08"]="Resume menu -> fresh install (option 2)"
    ["09"]="-h help flag"
    ["10"]="Clean install all modes (final)"
)

# Fast-only tests (default set)
FAST_TESTS="01 02 03 04 05 06 07 08 09"
# Full test set (includes slow-sequential and all)
ALL_TESTS="01 02 03 04 05 06 07 08 09 10"

# ================================================================
#  CLI Argument Parsing
# ================================================================

RUN_TESTS=""
RUN_ALL=false
LIST_ONLY=false

while [ $# -gt 0 ]; do
    case "$1" in
        --all)
            RUN_ALL=true
            shift
            ;;
        --list)
            LIST_ONLY=true
            shift
            ;;
        --test)
            RUN_TESTS="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--all] [--list] [--test N,N,...] [-h]"
            echo ""
            echo "  (no args)  Run fast-mode tests only (T01-T09)"
            echo "  --all      Include slow-sequential + all modes (T01-T10)"
            echo "  --list     List all test cases"
            echo "  --test N   Run specific test(s), e.g. --test 5 or --test 4,5,6"
            exit 0
            ;;
        *)
            echo "Unknown option: $1 (use -h for help)"
            exit 1
            ;;
    esac
done

# ================================================================
#  Main
# ================================================================

# Initialize conda
eval "$(conda shell.bash hook 2>/dev/null)" || {
    echo "ERROR: Cannot initialize conda. Please run 'conda init' first."
    exit 1
}

if $LIST_ONLY; then
    echo ""
    echo "Available tests:"
    for id in 01 02 03 04 05 06 07 08 09 10; do
        desc="${TEST_DESCS[$id]}"
        func="${TEST_FUNCS[$id]}"
        echo "  T${id}  ${desc}"
    done
    echo ""
    echo "  Default (fast-only): T01-T09  (~40 min)"
    echo "  With --all:          T01-T10  (~60 min)"
    exit 0
fi

# Determine test set
if [ -n "$RUN_TESTS" ]; then
    SELECTED="$RUN_TESTS"
elif $RUN_ALL; then
    SELECTED="$ALL_TESTS"
else
    SELECTED="$FAST_TESTS"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     SignalP 6.0 v15 暴力测试 / Stress Test Suite          ║"
echo "╠═══════════════════════════════════════════════════════════╣"
printf "║  Installer: %-45s ║\n" "$INSTALLER"
printf "║  Log dir:   %-45s ║\n" "$LOG_DIR"
printf "║  Tests:     %-45s ║\n" "$(echo $SELECTED | tr ' ' ', ')"
printf "║  Started:   %-45s ║\n" "$(date '+%Y-%m-%d %H:%M:%S')"
echo "╚═══════════════════════════════════════════════════════════╝"

# Init results file
echo "# SignalP 6.0 v15 Stress Test Results" > "$RESULTS_FILE"
echo "# Date: $(date)" >> "$RESULTS_FILE"
echo "# Installer: $INSTALLER" >> "$RESULTS_FILE"
echo "# RESULT|TEST_ID|NAME|ELAPSED_SECONDS" >> "$RESULTS_FILE"

# Run selected tests
for id in $SELECTED; do
    func="${TEST_FUNCS[$id]}"
    desc="${TEST_DESCS[$id]}"
    if [ -z "$func" ]; then
        log_info "Unknown test ID: $id, skipping"
        continue
    fi
    run_test "$id" "$desc" "$func"
done

# ================================================================
#  Summary
# ================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                      测试总结 / Summary                   ║"
echo "╠═══════════════════════════════════════════════════════════╣"
printf "║  Total / 总计:  ${BOLD}%-3d${NC}                                        ║\n" "$TOTAL"
printf "║  Pass / 通过:   ${GREEN}%-3d${NC}                                        ║\n" "$PASS"
printf "║  Fail / 失败:   ${RED}%-3d${NC}                                        ║\n" "$FAIL"
printf "║  Skip / 跳过:   ${YELLOW}%-3d${NC}                                        ║\n" "$SKIP"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

echo "Detailed results:"
echo "─────────────────────────────────────────────────────────────"
printf "  %-6s %-45s %-10s\n" "ID" "TEST" "TIME"
echo "─────────────────────────────────────────────────────────────"
while IFS='|' read -r result tid name elapsed; do
    [[ "$result" == '#'* ]] && continue
    case "$result" in
        PASS) color="$GREEN" ;;
        FAIL) color="$RED" ;;
        *)    color="$NC" ;;
    esac
    printf "  ${color}%-6s %-45s %-10s${NC}\n" "$tid" "${TEST_DESCS[${tid#T}]}" "${elapsed}s"
done < "$RESULTS_FILE"
echo "─────────────────────────────────────────────────────────────"
echo ""

echo "Log directory: $LOG_DIR"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 ALL TESTS PASSED! v15 暴力测试完成！${NC}"
else
    echo -e "${RED}${BOLD}⚠ $FAIL test(s) failed. Check logs in: $LOG_DIR${NC}"
fi

# Final cleanup
cleanup 2>/dev/null

exit $FAIL
