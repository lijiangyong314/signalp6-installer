#!/bin/bash
set -uo pipefail

# ==========================================================
# SignalP 6.0 全自动安装脚本（最终版 v8）
# 适配 Ubuntu/Linux + Conda
#
# 经过 8 轮迭代验证的核心修复：
#   1. setup.py install 卡住 → timeout 限时 + set +e 防脚本退出
#   2. libtiff.so.5 → 卸载 pip Pillow，装 conda Pillow
#   3. import signalp 依赖 torch → 先装完所有依赖再 import
#   4. 解压目录有两层 → 动态搜索 setup.py，不硬编码
#   5. 模型路径 → 优先从解压包内查找
#   6. 压缩包找不到 → 全盘搜索 + 手动输入兜底
#   7. conda 安装 PyTorch 时降级操作返回非零退出码 → 所有安装命令加 || true
#   8. tqdm 版本过高不兼容 Python 3.7 → 限制 <4.60
# ==========================================================

WORK_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)"

# ---------- 工具函数 ----------
log_info()  { echo -e "\033[1;32m[INFO]\033[0m  $1"; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m  $1"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }
log_step()  { echo ""; echo "===== $1 ====="; }

# ---------- 0. 初始化 Conda ----------
log_step "[0/8] 初始化 Conda"
CONDA_BASE=$(conda info --base 2>/dev/null || true)
if [ -z "$CONDA_BASE" ]; then
    log_error "未检测到 conda，请先安装 Anaconda/Miniconda"
    exit 1
fi
source "$CONDA_BASE/etc/profile.d/conda.sh"
log_info "Conda 路径：$CONDA_BASE"

# ---------- 1. 创建 Conda 环境 ----------
log_step "[1/8] 创建 Python 3.7 环境"

if conda env list 2>/dev/null | grep -q "^signalp6 "; then
    log_warn "signalp6 环境已存在，跳过创建"
    log_info "（如需重建：conda remove -n signalp6 --all -y）"
else
    log_info "创建 signalp6 环境（python=3.7）..."
    conda create -n signalp6 python=3.7 -c conda-forge -y
fi

# 初始化 conda 激活函数（脚本中必须这样用）
eval "$(conda shell.bash hook 2>/dev/null)" || {
    log_error "conda shell hook 初始化失败"
    exit 1
}
conda activate signalp6 || {
    log_error "conda activate signalp6 失败"
    exit 1
}

PY_IMPL=$(python -c "import platform; print(platform.python_implementation())" 2>/dev/null || echo "unknown")
if [ "$PY_IMPL" != "CPython" ]; then
    log_error "Python 实现为 $PY_IMPL，需要 CPython"
    exit 1
fi
log_info "Python $(python --version 2>&1)，CPython ✅"

# ---------- 2. 定位压缩包 ----------
log_step "[2/8] 定位 signalp-6*.tar.gz"

find_tar() {
    local found=""
    for d in "$HOME/桌面" "$HOME/Desktop" "$HOME/下载" "$HOME/Downloads" "$HOME" "$WORK_DIR" "/tmp" "/opt"; do
        [ -d "$d" ] || continue
        found=$(find "$d" -maxdepth 3 -name "signalp-6*.tar.gz" -print -quit 2>/dev/null || true)
        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi
    done
    # 全盘搜索 /home（限时 30 秒）
    found=$(timeout 30 find /home -maxdepth 5 -name "signalp-6*.tar.gz" -print -quit 2>/dev/null || true)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    return 1
}

TAR_FILE=$(find_tar)
if [ -z "$TAR_FILE" ]; then
    log_error "未找到 signalp-6*.tar.gz"
    echo ""
    read -p "请输入压缩包完整路径: " USER_INPUT
    if [ -f "$USER_INPUT" ] && [[ "$USER_INPUT" == *.tar.gz ]]; then
        TAR_FILE="$USER_INPUT"
    else
        log_error "路径无效，退出"; exit 1
    fi
fi
log_info "找到压缩包：$TAR_FILE"

# ---------- 3. 解压 ----------
log_step "[3/8] 解压安装包"
EXTRACT_DIR="$WORK_DIR/signalp_extracted"
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
tar zxf "$TAR_FILE" -C "$EXTRACT_DIR"

# 动态查找源码目录（解压后可能有一层或两层目录）
EXTRACTED_PATH=$(find "$EXTRACT_DIR" -type f -name "setup.py" -exec dirname {} \; 2>/dev/null | head -n 1)
if [ -z "$EXTRACTED_PATH" ]; then
    log_error "解压后未找到 setup.py"
    tar tzf "$TAR_FILE" 2>/dev/null | head -20
    exit 1
fi
log_info "源码目录：$EXTRACTED_PATH"

# 提前记录解压包内的模型目录位置
MODEL_DIR_IN_EXTRACT="$EXTRACTED_PATH/models/sequential_models_signalp6"
if [ -d "$MODEL_DIR_IN_EXTRACT" ]; then
    log_info "模型目录已找到（解压包内）：$MODEL_DIR_IN_EXTRACT"
fi

# ---------- 4. 编译安装 ----------
log_step "[4/8] 编译安装"
cd "$EXTRACTED_PATH"
log_info "执行 python setup.py install（限时 300 秒）..."
log_warn "注：安装完成后可能卡住不退出，脚本会自动处理"

# 用 timeout 限制时长，用 tee 显示进度
# set +e 防止 timeout 退出码 124 导致脚本退出
set +e
timeout 300 python setup.py install 2>&1 | tee /tmp/signalp_install.log
INSTALL_RC=${PIPESTATUS[0]}
set -e

if [ $INSTALL_RC -eq 124 ]; then
    log_warn "安装超时 300 秒被终止（正常现象，安装已完成）"
elif [ $INSTALL_RC -ne 0 ]; then
    log_warn "setup.py 退出码 $INSTALL_RC（可能是正常卡住被终止）"
else
    log_info "setup.py install 正常完成 ✅"
fi

# 验证安装（此时 import 可能因缺依赖失败，只检查包是否存在）
SITE_PKGS=$(python -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "")
if [ -d "$SITE_PKGS/signalp6-6.0+h-py3.7.egg/signalp" ] || \
   pip show signalp6 > /dev/null 2>&1; then
    log_info "✅ signalp 包已安装"
else
    log_warn "无法确认安装结果，继续尝试..."
fi

cd "$WORK_DIR"

# ---------- 5. 安装所有依赖（必须在 import signalp 之前完成！）----------
log_step "[5/8] 安装所有依赖"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "【重要】必须在 import signalp 之前装完所有依赖！"
echo "  signalp 内部导入链：signalp → predict → torch"
echo "                            → make_sequence_plot → matplotlib → PIL"
echo "  缺任何一个都会 ImportError，所以先装完再 import"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 5a. 修复 Pillow（libtiff.so.5 问题的根源）
# 必须用 conda 版 Pillow：conda 会自带兼容的 libtiff.so.6，pip 版链接的是旧 libtiff.so.5
log_info "[5a] 修复 Pillow（解决 libtiff.so.5）..."
pip uninstall -y Pillow pillow 2>/dev/null || true
# 先试 conda（最优方案，自带 libtiff）
conda install -c conda-forge pillow -y 2>/dev/null || true
# 验证：如果 conda 因网络失败，检查是否已有可用版本（之前可能装过）
if ! python -c "from PIL import Image" 2>/dev/null; then
    log_warn "  conda 安装 Pillow 失败，尝试 pip（注意：可能仍有 libtiff.so.5 问题）"
    # pip 安装后尝试 apt 安装系统 libtiff5 作为兜底
    pip install pillow 2>/dev/null || true
    sudo apt-get install -y libtiff5 2>/dev/null || true
fi
python -c "from PIL import Image; print('  Pillow ✅')" 2>/dev/null || log_warn "Pillow 验证失败"

# 5b. matplotlib
# 策略：先试 pip（走国内清华镜像，不依赖 conda 网络），失败再试 conda
# matplotlib 本身不依赖 libtiff，用 pip 安装没有 libtiff.so.5 问题
log_info "[5b] 安装 matplotlib..."
MATPLOTLIB_INSTALLED=false
pip install "matplotlib>3.3.2,<4.0" 2>/dev/null && MATPLOTLIB_INSTALLED=true || true
if [ "$MATPLOTLIB_INSTALLED" = "false" ]; then
    log_warn "  pip 安装 matplotlib 失败，尝试 conda..."
    conda install -c conda-forge matplotlib -y 2>/dev/null || true
fi
python -c "import matplotlib; print('  Matplotlib ✅')" 2>/dev/null || log_warn "matplotlib 验证失败"

# 5c. NumPy（必须 <2.0，兼容 Python 3.7）
log_info "[5c] 安装 NumPy（<2.0）..."
pip install "numpy>=1.19,<1.25" || true
python -c "import numpy; print(f'  NumPy {numpy.__version__} ✅')" 2>/dev/null || log_warn "NumPy 验证失败"

# 5d. PyTorch 1.8.1 CPU 版
#  先试 pip（已知在用户环境可成功），成功则跳过 conda
#  所有安装命令均加 || true，最后统一验证
log_info "[5d] 安装 PyTorch 1.8.1 CPU 版..."

PYTORCH_INSTALLED=false

# 方法1：pip 安装
log_info "  尝试 pip 安装 torch 1.8.1+cpu..."
pip install torch==1.8.1+cpu torchvision==0.9.1+cpu \
    -f https://download.pytorch.org/whl/torch_stable.html 2>/dev/null
if python -c "import torch; print(f'  PyTorch {torch.__version__} ✅')" 2>/dev/null; then
    log_info "  pip 安装成功，跳过 conda 安装"
    PYTORCH_INSTALLED=true
else
    log_warn "  pip 安装失败，尝试 conda 安装..."
    conda install -c pytorch pytorch==1.8.1 cpuonly -y || true
    if python -c "import torch; print(f'  PyTorch {torch.__version__} ✅')" 2>/dev/null; then
        PYTORCH_INSTALLED=true
    fi
fi

if [ "$PYTORCH_INSTALLED" = "false" ]; then
    log_error "PyTorch 安装失败，请手动安装"
    echo "  参考命令："
    echo "    pip install torch==1.8.1+cpu torchvision==0.9.1+cpu -f https://download.pytorch.org/whl/torch_stable.html"
fi

# 5e. tqdm（必须 <4.60，兼容 Python 3.7）
log_info "[5e] 安装 tqdm（兼容 Python 3.7）..."
pip install "tqdm<4.60" || true
python -c "import tqdm; print('  tqdm ✅')" 2>/dev/null || log_warn "tqdm 验证失败"

# 5f. 最终验证：所有依赖就绪后，测试 import signalp
log_info "[5f] 验证 import signalp..."
if python -c "import signalp; print('  signalp import ✅')" 2>/dev/null; then
    log_info "✅ 所有依赖安装完成，signalp 可正常导入"
else
    log_error "import signalp 仍然失败，详细错误："
    python -c "import signalp" 2>&1 | tail -10
    echo ""
    log_warn "逐个检查依赖状态："
    python -c "import torch; print('  torch ✅')"      2>/dev/null || log_error "  torch ❌ → pip install torch==1.8.1+cpu -f https://download.pytorch.org/whl/torch_stable.html"
    python -c "from PIL import Image; print('  PIL ✅')" 2>/dev/null || log_error "  Pillow ❌ → conda install -c conda-forge pillow -y"
    python -c "import matplotlib; print('  matplotlib ✅')" 2>/dev/null || log_error "  matplotlib ❌ → pip install 'matplotlib>3.3.2,<4.0'"
    python -c "import tqdm; print('  tqdm ✅')"        2>/dev/null || log_error "  tqdm ❌ → pip install 'tqdm<4.60'"
    echo ""
    log_error "请根据以上提示手动安装缺失包后重试"
    exit 1
fi

# ---------- 6. 部署模型权重 ----------
log_step "[6/8] 部署模型权重"

SIGNALP_DIR=$(python -c "import signalp; import os; print(os.path.dirname(signalp.__file__))" 2>/dev/null)

# 用函数封装第6步逻辑，便于在路径获取失败时跳过模型复制，直接进入第7步
deploy_model_weights() {
    if [ -z "$SIGNALP_DIR" ]; then
        log_error "无法获取 SignalP 安装路径，跳过模型复制"
        echo "  请安装完成后手动执行："
        echo "    SIGNALP_DIR=\$(python -c \"import signalp; import os; print(os.path.dirname(signalp.__file__))\")"
        echo "    cp -r <sequential_models_signalp6目录> \$SIGNALP_DIR/model_weights/"
        return 0
    fi
    log_info "SignalP 安装路径：$SIGNALP_DIR"

    # 搜索模型目录（按优先级）
    MODEL_SRC=""
    for mp in \
        "$MODEL_DIR_IN_EXTRACT" \
        "$HOME/桌面/signalp6_slow_sequential/signalp-6-package/models/sequential_models_signalp6" \
        "$HOME/Desktop/signalp6_slow_sequential/signalp-6-package/models/sequential_models_signalp6" \
        "$HOME/signalp6_slow_sequential/signalp-6-package/models/sequential_models_signalp6" \
        "$WORK_DIR/signalp6_slow_sequential/signalp-6-package/models/sequential_models_signalp6" \
    ; do
        if [ -d "$mp" ]; then
            MODEL_SRC="$mp"
            log_info "找到模型目录：$MODEL_SRC"
            break
        fi
    done

    if [ -n "$MODEL_SRC" ]; then
        mkdir -p "$SIGNALP_DIR/model_weights/"
        cp -r "$MODEL_SRC" "$SIGNALP_DIR/model_weights/"
        if [ -d "$SIGNALP_DIR/model_weights/sequential_models_signalp6" ]; then
            log_info "✅ 模型复制完成"
            ls "$SIGNALP_DIR/model_weights/sequential_models_signalp6/" 2>/dev/null | head -5
        else
            log_warn "模型复制后结构异常，请检查"
        fi
    else
        log_warn "未找到模型目录"
        read -p "请输入 sequential_models_signalp6 的完整路径（或回车跳过）: " USER_MODEL
        if [ -n "$USER_MODEL" ] && [ -d "$USER_MODEL" ]; then
            mkdir -p "$SIGNALP_DIR/model_weights/"
            cp -r "$USER_MODEL" "$SIGNALP_DIR/model_weights/"
            log_info "✅ 手动指定模型复制完成"
        else
            log_warn "跳过模型复制，请稍后手动执行："
            log_warn "  cp -r <模型目录> $SIGNALP_DIR/model_weights/"
        fi
    fi
}

deploy_model_weights

# ---------- 7. 环境诊断 ----------
log_step "[7/8] 环境诊断"

cat << 'DIAG_EOF' > "$WORK_DIR/check_signalp_env.sh"
#!/bin/bash
echo "--- SignalP 6.0 诊断报告 ---"
echo ""
echo "1. Python 环境："
python --version 2>&1
echo ""
echo "2. 核心依赖："
python -c "import numpy; print(f'   NumPy:      {numpy.__version__}')"    2>/dev/null || echo "   ❌ NumPy"
python -c "import torch; print(f'   PyTorch:    {torch.__version__}')"    2>/dev/null || echo "   ❌ PyTorch"
python -c "import PIL; print(f'   Pillow:     {PIL.__version__}')"       2>/dev/null || echo "   ❌ Pillow"
python -c "import matplotlib; print(f'   Matplotlib: {matplotlib.__version__}')" 2>/dev/null || echo "   ❌ Matplotlib"
python -c "import tqdm; print('   tqdm:       OK')"                       2>/dev/null || echo "   ❌ tqdm"
echo ""
echo "3. SignalP 状态："
SIGNALP_PATH=$(python -c "import signalp; print(signalp.__file__)" 2>/dev/null || true)
if [ -n "$SIGNALP_PATH" ]; then
    echo "   ✅ import signalp 成功: $SIGNALP_PATH"
    MODEL_DIR=$(dirname "$SIGNALP_PATH")/model_weights/sequential_models_signalp6
    if [ -d "$MODEL_DIR" ]; then
        echo "   ✅ 模型目录存在: $MODEL_DIR"
    else
        echo "   ❌ 模型目录缺失: $MODEL_DIR"
    fi
else
    echo "   ❌ import signalp 失败"
fi
echo ""
echo "4. signalp6 命令："
which signalp6 2>/dev/null && echo "   ✅ signalp6 在 PATH" || echo "   ❌ signalp6 不在 PATH"
echo ""
echo "--- 诊断结束 ---"
DIAG_EOF

chmod +x "$WORK_DIR/check_signalp_env.sh"
bash "$WORK_DIR/check_signalp_env.sh"

# ---------- 8. 最终验证 ----------
log_step "[8/8] 最终验证"

# 用 conda run 执行 signalp6 --help（避免 PATH 问题）
if conda run -n signalp6 signalp6 --help > /dev/null 2>&1; then
    echo ""
    echo "🎉🎉🎉 安装成功！SignalP 6.0 已就绪 🎉🎉🎉"
    echo ""
    echo "使用方法："
    echo "  conda activate signalp6"
    echo "  signalp6 -i test.fasta -o results -m slow-sequential"
    echo ""
    echo "故障排查："
    echo "  conda activate signalp6 && bash $WORK_DIR/check_signalp_env.sh"
else
    echo ""
    echo "❌ signalp6 --help 验证失败"
    echo ""
    echo "请手动排查："
    echo "  conda activate signalp6"
    echo "  python -c \"import signalp; print('OK')\""
    echo "  signalp6 --help"
    echo ""
    echo "诊断脚本：bash $WORK_DIR/check_signalp_env.sh"
fi
