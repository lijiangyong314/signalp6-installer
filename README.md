# 🧬 SignalP 6.0 Automated Installer | SignalP 6.0 全自动安装脚本

<div align="center">

**One-command deployment for SignalP 6.0 (fast + slow-sequential) on Ubuntu/Linux + Conda**
**一键部署 SignalP 6.0（fast + slow-sequential 模型）**

[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-orange?logo=ubuntu)](https://ubuntu.com/)
[![Conda](https://img.shields.io/badge/Conda-Miniconda%7CAnaconda-green?logo=conda-forge)](https://docs.conda.io/en/latest/miniconda.html)
[![Python](https://img.shields.io/badge/Python-3.7-blue?logo=python&logoColor=white)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[English](#english--signalp-60-automated-installer) | [中文](#信号肽-60-全自动安装脚本)

</div>

<!-- Keywords for SEO / 搜索引擎关键词优化 -->
<!--
Keywords: SignalP 6.0, signal peptide prediction, transmembrane domain, bioinformatics,
deep learning protein analysis, DTU Health Tech, Ubuntu installation, conda installer,
libtiff.so.5 fix, PyTorch CPU, fast model, slow-sequential model, automated setup script, Linux bioinformatics
关键词：SignalP 6.0, 信号肽预测, 跨膜蛋白, 生物信息学, 深度学习蛋白质分析, DTU, Ubuntu 安装,
conda 自动安装, libtiff.so.5 修复, PyTorch CPU, fast 模型, slow-sequential 模型, 一键安装脚本, Linux 生物信息学
-->

---

## ✨ 为什么需要这个脚本？

SignalP 6.0 是 DTU Health Tech 开发的**信号肽与跨膜区域预测工具**，基于深度学习，是目前该领域最先进的工具之一。但官方只提供了手动安装步骤，在 Ubuntu/Linux + Conda 环境下存在**多个已知的兼容性问题**，手动排查非常耗时。

本脚本经过 **15 轮迭代验证**（v1 → v15），将繁琐的 8 步手动安装简化为**一条命令**，并自动修复了所有已知故障点。

> 💡 **适用场景**：生物信息学研究、蛋白质序列分析、信号肽预测、跨膜蛋白鉴定

---

## 🆕 v15 新特性

| 特性 | 说明 |
|------|------|
| **🔄 断点续装** | 安装中断后（网络超时、Ctrl+C、关机等）再次运行脚本，自动从断点恢复，无需从头开始 |
| **📦 Conda 自动安装** | 未安装 Conda 时自动下载并安装 Miniconda3，无需预先准备 |
| **🔮 前向兼容** | 动态发现 .egg 目录、模型文件、压缩包；版本集中配置，SignalP 更新后只需改顶部几行 |
| **🐛 Bug 修复** | 修复 nounset、shell 注入、环境健康检查、模式显示、模型完整性校验、`set -e` 意外启用等 7 个 bug |

---

## ⚠️ 重要限制

| 项目 | 说明 |
|------|------|
| **支持模型** | ✅ `fast`（蒸馏模型，速度最快）和 `slow-sequential`（顺序模型，最高精度） |
| **智能识别** | ✅ 自动解析 `signalp-[0-9]*.tar.gz` 文件名，按模式分组并保留最高版本 |
| **操作系统** | Ubuntu 18.04+ / Debian 10+（其他 Linux 发行版可能需调整） |
| **Python** | 必须为 **CPython 3.7**（PyPy 不支持） |
| **Conda** | Miniconda3 / Anaconda（**未安装时脚本会自动安装**） |

> 📌 脚本会自动扫描目录中的所有 SignalP 压缩包，交互式让你选择安装哪些模式。如果同模式有多个版本，自动保留最高版本。

---

## 📋 前置条件

| 条件 | 要求 | 说明 |
|------|------|------|
| **操作系统** | Ubuntu 18.04+ / Debian 10+ | 已测试 Ubuntu 22.04 |
| **Conda** | Miniconda3 / Anaconda | **可选** — 未安装时脚本会自动下载安装 |
| **网络连接** | 可访问 PyPI / conda-forge / PyTorch 下载源 | 🇨🇳 中国用户建议配置镜像（见下方） |
| **SignalP 安装包** | 从 [DTU Health Tech](https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0) 下载 `signalp-[0-9]*.tar.gz`（支持 **fast** 和 **slow-sequential** 版本） |

### 🇨🇳 中国用户网络优化（推荐）

如果访问 PyPI / conda-forge 较慢，建议提前配置镜像：

```bash
# pip 使用清华镜像
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# conda 使用清华镜像
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/
conda config --set show_channel_urls yes
```

### 📦 获取 SignalP 安装包

1. 访问 [DTU Health Tech 注册页面](https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0)
2. 填写学术用途申请表（**免费**，仅限非商业学术用途）
3. 收到下载链接后，下载 `signalp-[0-9]*.tar.gz`（支持 **fast** 和 **slow-sequential** 版本，可同时下载多个）
4. 将压缩包放置于以下任一目录：
   - `~/Desktop` 或 `~/桌面`
   - `~/Downloads` 或 `~/下载`
   - 脚本所在目录
   - **任意位置**（脚本也会自动全盘搜索）

> 📌 **学术许可提醒**：SignalP 6.0 仅限非商业学术研究用途，请遵守 DTU 的许可协议。

---

## 🚀 快速开始（3 步搞定）

### Step 1：准备安装包

将下载的 `signalp-[0-9]*.tar.gz` 放入上述目录之一。

### Step 2：下载并运行脚本

**方式 A：仅下载脚本（中文双语版 / Bilingual）**

```bash
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v15.sh
chmod +x install_signalp6_v15.sh
./install_signalp6_v15.sh
```

**方式 A2：仅下载脚本（英文版 / English）**

```bash
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v15_en.sh
chmod +x install_signalp6_v15_en.sh
./install_signalp6_v15_en.sh
```

**方式 B：克隆完整仓库（含 README 文档 + 脚本，推荐）**

```bash
git clone https://github.com/lijiangyong314/signalp6-installer.git
cd signalp6-installer
chmod +x install_signalp6_v15.sh
./install_signalp6_v15.sh
```

> 💡 **推荐方式 B**：一条命令拿到脚本 + 完整文档，以后 `git pull` 还能自动获取更新。

### Step 3：验证安装

```bash
conda activate signalp6
signalp6 --help
```

成功的话会显示 SignalP 6.0 的帮助信息。看到 `🎉 安装成功！` 的提示即表示一切就绪 ✅

---

## 🔄 断点续装

v15 新增断点续装功能。安装过程中无论因何种原因中断（网络超时、Ctrl+C、关机等），再次运行脚本时会显示：

```
╔═══════════════════════════════════════════════════════════╗
║     检测到未完成的安装 / Previous incomplete install       ║
╠═══════════════════════════════════════════════════════════╣
║  中断位置 / Interrupted at: 安装所有依赖 / Install dependencies
║  时间 / Time: 2026-05-27 20:09:52
║  模式 / Modes: fast slow-sequential
╚═══════════════════════════════════════════════════════════╝

  [1] 继续上次安装 / Resume from last checkpoint
  [2] 重新安装 / Fresh install (删除已有环境重新开始)
  [3] 退出 / Exit

请选择 [1-3] / Select [1-3]:
```

选择 `[1]` 即可从断点无缝恢复，已完成的步骤自动跳过。

---

## 🔍 脚本执行流程详解

脚本共分为 **8 个步骤**，每步都有详细的日志输出和错误处理：

```
[0/8] 初始化 Conda          ← 检测 Conda 路径 + 激活 shell hook（未安装则自动下载 Miniconda3）
[1/8] 创建 Python 3.7 环境   ← 创建 signalp6 conda 环境（CPython）
[2/8] 查找压缩包（智能去重） ← 自动搜索常用目录 + 全盘扫描 + 手动输入兜底
[3/8] 按需解压安装包        ← 动态搜索 setup.py（兼容非标准目录名）
[4/8] 编译安装              ← timeout 300s 限时执行 setup.py install
[5/8] 安装所有依赖           ← Pillow → matplotlib → NumPy → PyTorch → tqdm → import 验证
[6/8] 部署模型权重          ← 完整性校验 + 动态发现 fallback
[7/8] 环境诊断              ← 生成 check_signalp_env.sh 诊断脚本
[8/8] 最终验证             ← 执行 signalp6 --help
```

### 各步骤关键要点

| 步骤 | 功能 | 关键技术细节 |
|:----:|------|-------------|
| **0** | 初始化 Conda | 常见路径搜索 + 未安装时自动下载 Miniconda3 + `eval "$(conda shell.bash hook)"` |
| **1** | 创建环境 | 强制检查 Python 实现为 CPython（PyPy 不兼容 PyTorch），已存在且健康则跳过 |
| **2** | 定位压缩包 | 多级搜索策略：常用目录 → 工作目录 → `/home` 全盘搜索（限时 30 秒）→ 手动输入；智能去重保留最高版本 |
| **3** | 解压 | 用 `find -name setup.py` 动态定位源码目录，不硬编码路径；幂等（已解压则跳过） |
| **4** | 编译安装 | `timeout 300` 防卡死 + `PIPESTATUS` 正确获取退出码 + `.egg` 目录动态发现 |
| **5a** | **Pillow 修复** | **核心修复**：卸载 pip 版 Pillow → 改装 conda-forge 版，彻底解决 `libtiff.so.5` 缺失问题 |
| **5b** | matplotlib | 版本约束 `>3.3.2,<5.0`，pip 优先（走国内镜像），回退 conda |
| **5c** | NumPy | 版本限制 `>=1.19,<2.0` 以兼容 Python 3.7，已安装则跳过 |
| **5d** | PyTorch | 优先 pip 安装 1.8.1+cpu（CPU only），失败自动回退 conda |
| **5e** | tqdm | 版本限制 `<4.66`（4.67+ 使用了 Python 3.8+ 的 `importlib.metadata`） |
| **5f** | import 验证 | 所有依赖就绪后才尝试 `import signalp`，失败时逐项提示缺失项 |
| **6** | 模型权重 | 完整性校验（`du -sb` + `find -type f` 对比源/目标）+ 动态发现 fallback |
| **7** | 诊断 | 生成独立可复用的 `check_signalp_env.sh` 脚本（动态发现模型文件） |
| **8** | 最终验证 | 用 `conda run` 执行 `signalp6 --help` 避免 PATH 问题 |

---

## 📖 使用方法

### 基本用法

```bash
# 激活环境
conda activate signalp6

# 运行预测
signalp6 --fastafile input.fasta --output_dir output_dir --mode fast
signalp6 --fastafile input.fasta --output_dir output_dir --mode slow-sequential

# 查看完整帮助
signalp6 --help
```

### 常用参数

| 参数 | 短选项 | 说明 | 默认值 |
|------|--------|------|--------|
| `--fastafile` | `-ff` / `-fasta` / `-i` | 输入 FASTA 文件路径 | 必填 |
| `--output_dir` | `-od` / `-o` | 输出目录 | 必填 |
| `--mode` | `-m` | 运行模式 | `fast` |
| `--organism` | `-org` | 生物体类型 | `other` |
| `--format` | `-fmt` / `-f` | 输出格式（`txt`/`png`/`eps`/`all`/`none`） | `txt` |
| `--bsize` | `-bs` / `-batch` | 批处理大小 | `10` |
| `--torch_num_threads` | `-tt` | PyTorch 线程数 | `8` |
| `--write_procs` | `-wp` | 并行写入进程数 | `8` |
| `--skip_resolve` | | 跳过 Viterbi 路径冲突解析 | `False` |

### 示例：分析真核生物蛋白质（slow-sequential 模式）

```bash
conda activate signalp6

signalp6 \
  --fastafile my_proteins.fasta \
  --output_dir signalp_results \
  --mode slow-sequential \
  --organism euk \
  --format all \
  --torch_num_threads 4
```

### 示例：快速预测（fast 模式）

```bash
conda activate signalp6

signalp6 \
  --fastafile my_proteins.fasta \
  --output_dir signalp_results \
  --mode fast \
  --format txt
```

---

## 🛠️ 故障排查

### 一键诊断

安装后或遇到问题时，先运行诊断脚本：

```bash
conda activate signalp6
bash check_signalp_env.sh
```

这会输出完整的依赖状态报告：

```
╔════════════════════════════════════════════════════════╗
║           SignalP 环境诊断报告 (v15)                    ║
╚════════════════════════════════════════════════════════╝

1. Python 环境 / Python environment:
   Python 3.7.12 (CPython)

2. 核心依赖 / Core dependencies:
   NumPy:       1.21.6
   PyTorch:     1.8.1+cpu
   Pillow:      9.2.0
   Matplotlib:  3.5.3
   tqdm:       OK

3. SignalP 状态 / SignalP status:
   ✅ import signalp 成功 / success

4. 模型权重状态（model_weights/）/ Model weights status:
   ✅ distilled_model_signalp6.pt - 1.6G
   ✅ sequential_models_signalp6/ - 7 文件 / files, 9.2G

5. signalp6 命令 / signalp6 command:
   ✅ signalp6 在 PATH / in PATH

══════════════════ 诊断结束 / Diagnostics complete ═════════════
```

### 常见问题速查表

| 错误信息 | 原因 | 解决方案 |
|----------|------|---------|
| `ImportError: libtiff.so.5` | pip 版 Pillow 链接旧版 .so 文件 | `pip uninstall -y Pillow && conda install -c conda-forge pillow -y` |
| `No module named 'torch'` | PyTorch 未正确安装 | `pip install torch==1.8.1+cpu torchvision==0.9.1+cpu -f https://download.pytorch.org/whl/torch_stable.html` |
| `No module named 'signalp'` | 依赖安装顺序错误 | **必须**先装完所有依赖再 import signalp（重新运行脚本即可） |
| `setup.py install` 卡住不退出 | setuptools egg 写入过程卡死 | 正常现象，脚本已用 `timeout 300` 自动处理；也可按 `Ctrl+C` 手动终止 |
| `'tqdm' has no attribute 'auto'` | tqdm 版本过高不兼容 Python 3.7 | `pip install "tqdm<4.66"` |
| `ModuleNotFoundError: No module named 'matplotlib'` | matplotlib 未安装 | `pip install "matplotlib>3.3.2,<5.0"` |
| `conda activate` 在脚本中无效 | non-interactive shell 限制 | 使用 `eval "$(conda shell.bash hook)"` 替代直接 source |
| conda 网络超时 | 无法连接 repo.anaconda.com | 配置清华镜像（见上方「中国用户网络优化」） |
| `找不到 signalp-[0-9]*.tar.gz` | 压缩包不在搜索路径内 | 将压缩包移到 `~/Desktop`/`~/Downloads`，或脚本会提示手动输入路径 |
| 模型权重缺失 | 解压包内无模型目录 | 手动复制：`cp -r <source>/sequential_models_signalp6 $SIGNALP_DIR/model_weights/` |
| `signalp6: command not found` | 未激活 conda 环境 | 先执行 `conda activate signalp6` |
| `Python implementation is PyPy` | 环境使用了 PyPy | 删除重建环境：`conda remove -n signalp6 --all -y && ./install_signalp6_v15.sh` |

### 手动修复流程

如果自动安装失败，可以按以下顺序手动修复：

```bash
# 1. 激活环境
conda activate signalp6

# 2. 重装 Pillow（解决 libtiff.so.5）
pip uninstall -y Pillow pillow
conda install -c conda-forge pillow -y

# 3. 安装 PyTorch CPU 版
pip install torch==1.8.1+cpu torchvision==0.9.1+cpu \
  -f https://download.pytorch.org/whl/torch_stable.html

# 4. 安装其余依赖
pip install "numpy>=1.19,<2.0"
pip install "matplotlib>3.3.2,<5.0"
pip install "tqdm<4.66"

# 5. 验证
python -c "import signalp; print('✅ SignalP 就绪')"

# 6. 如果模型缺失，手动复制（替换 <path-to-models> 为实际路径）
SIGNALP_DIR=$(python -c "import signalp; import os; print(os.path.dirname(signalp.__file__))")
cp -r <path-to-models>/sequential_models_signalp6 $SIGNALP_DIR/model_weights/

# 7. 测试运行
signalp6 --help
```

---

## 🔬 技术细节：已知 Bug 与修复原理

以下是在官方安装文档中**完全未提及**的问题，全部在本脚本中自动修复：

### Bug #1：`ImportError: libtiff.so.5`

**现象**：
```
ImportError: libtiff.so.5: cannot open shared object file: No such file or directory
```

**根因**：
- 通过 `pip install pillow` 安装的 Pillow 会动态链接系统的 `libtiff.so.5`
- 但 Ubuntu 22.04 等新版系统只有 `libtiff.so.6`，没有 `.so.5`
- 这是 Pillow 的构建系统与新版 Linux 发行版的兼容性冲突

**修复**：
```bash
pip uninstall -y Pillow        # 卸载 pip 版
conda install -c conda-forge pillow -y  # 改用 conda-forge 版（自带兼容的 .so 链接）
```

### Bug #2：`setup.py install` 永久挂起

**现象**：`python setup.py install` 执行后**永远不会返回**，即使安装已完成。

**根因**：setuptools 在写入 egg-info 时进入某种死锁/阻塞状态（可能与特定版本的 setuptools + Python 3.7 组合有关）。

**修复**：
```bash
timeout 300 python setup.py install  # 限时 300 秒
# 退出码 124 = 被 timeout 终止（正常现象，安装已完成）
```

### Bug #3：`import signalp` 触发连锁 ImportError

**现象**：
```
ModuleNotFoundError: No module named 'torch'
# 或者
ImportError: libtiff.so.5
```

**根因**：SignalP 的导入链如下：
```
signalp → predict.py → torch (深度学习推理)
       → make_sequence_plot.py → matplotlib → PIL.Image (绘图)
```
任何一个环节缺失都会导致 `import signalp` 失败，而用户可能在**未装完所有依赖时就尝试 import**。

**修复**：脚本严格保证 **Step 5（安装所有依赖）→ Step 5f（验证 import）** 的顺序，不会跳过任何依赖。

### Bug #4：`tqdm.auto` AttributeError

**现象**：
```
AttributeError: module 'tqdm' has no attribute 'auto'
```

**根因**：tqdm ≥ 4.67 引入了 `tqdm.auto`，其内部使用 `importlib.metadata`（Python 3.8+ 特性），在 Python 3.7 上会报错。

**修复**：版本锁定 `pip install "tqdm<4.66"`。

### Bug #5：conda 降级操作非零退出码

**现象**：执行 `conda install pytorch==1.8.1 cpuonly -y` 时脚本意外退出。

**根因**：当 conda 需要降级某个包时，返回非零退出码，被 `set -e` 捕获后导致整个脚本终止。

**修复**：所有 conda/pip 安装命令末尾加 `|| true`，最后统一做 import 验证。

### Bug #6（v15）：`set -u` 导致 `set --` 误触发

**根因**：脚本使用 `set -uo pipefail`，但 `set --` 在 `set -u` 模式下对空数组会报 `unbound variable` 错误。

**修复**：在 `set --` 前临时关闭 `set -u`，执行后再恢复。

### Bug #7（v15）：`set -e` 被意外永久启用

**根因**：Step 4（编译安装）中为安全临时 `set +e` → `set -e`，但脚本原始状态是**无 `-e`** 的。`set -e` 从未被关闭，导致后续任何未保护的命令失败都会直接退出脚本（例如 PyTorch pip 安装失败时无法回退到 conda）。

**修复**：将 `set -e` 改回 `set +e`，恢复脚本的原始状态（`set -uo pipefail`）。

---

## 🗑️ 卸载方法

```bash
# 1. 删除 conda 环境（包含所有已安装的依赖）
conda remove -n signalp6 --all -y

# 2. （可选）删除脚本生成的临时文件
rm -rf ~/signalp_extracted*/      # 解压临时目录（如果在 Home 下）
rm -f ~/check_signalp_env.sh     # 诊断脚本

# 3. （可选）从 conda 环境列表确认已清理
conda env list | grep signalp    # 应该无输出
```

---

## ❓ FAQ（常见问题）

### Q1：为什么必须是 Python 3.7？
SignalP 6.0 官方要求 Python 3.7，因为其依赖的某些库（特别是早期版本的 torch 和相关绑定）对更高版本 Python 存在兼容性问题。脚本强制创建 Python 3.7 环境。

### Q2：fast 和 slow-sequential 有什么区别？
- **fast**：使用蒸馏模型（`distilled_model_signalp6.pt`，~1.5GB），预测速度最快，精度略低，适合大规模筛选
- **slow-sequential**：使用 7 个模型的集成（`sequential_models_signalp6/`，~9GB），精度最高但速度较慢（逐条处理），适合精细分析

两种模式可以同时安装，脚本会自动检测你有哪些安装包并交互式选择。

### Q3：安装大概需要多久？
取决于网络速度：
- **快速网络**（直连 PyPI）：~5 分钟
- **普通网络**（使用镜像）：~10 分钟
- **较慢网络**：~15-20 分钟
- 主要耗时在下载 PyTorch (~169MB CPU only) 和模型文件

### Q4：可以在服务器上运行吗？
可以！本脚本专为无 GUI 的 Linux 服务器设计。只需确保：
1. 将 `signalp-[0-9]*.tar.gz` 上传到服务器的任意目录
2. SSH 登录后运行脚本即可（未安装 Conda 会自动安装）

### Q5：如何确认安装是否完全成功？
运行以下三个命令，全部通过即表示安装完成：
```bash
conda activate signalp6
python -c "import signalp, torch, PIL, matplotlib; print('All imports OK')"
signalp6 --help
```

### Q6：可以在 Docker 容器中使用吗？
可以！基础镜像示例：
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y wget curl git
# 脚本会自动安装 Miniconda
COPY install_signalp6_v15.sh /opt/
COPY signalp-*.tar.gz /opt/
RUN cd /opt && bash install_signalp6_v15.sh
```

### Q7：安装中断了怎么办？
v15 支持断点续装。直接重新运行脚本，选择 `[1] 继续上次安装` 即可从断点恢复。

### Q8：脚本会修改系统环境吗？
不会。脚本的所有操作都在 conda 虚拟环境 `signalp6` 内进行，不涉及系统 Python 或全局包管理。

---

## 📊 安装流程图

```
┌───────────────────────────────────────────────────────┐
│            SignalP 6.0 自动安装流程 (v15)               │
├───────────────────────────────────────────────────────┤
│                                                       │
│  ┌─────────┐                                         │
│  │ 准备工作  │  signalp-[0-9]*.tar.gz                 │
│  │ (Conda   │  (未安装会自动下载 Miniconda3)            │
│  │  可选)   │                                         │
│  └────┬────┘                                         │
│       ▼                                               │
│  ┌─────────────┐                                     │
│  │ 运行脚本     │  ./install_signalp6_v15.sh          │
│  │ (中断可恢复) │  🔄 Checkpoint Resume                │
│  └────┬────────┘                                     │
│       ▼                                               │
│  ┌─────────────────────────────────────┐             │
│  │ Step 0-4: 环境准备 & 编译安装         │             │
│  │ • 自动检测/安装 Conda                 │             │
│  │ • 创建 signalp6 (Python 3.7) 环境     │             │
│  │ • 搜索 & 智能去重 tar.gz              │             │
│  │ • timeout 300 setup.py install       │             │
│  └──────────────┬──────────────────────┘             │
│                 ▼                                      │
│  ┌─────────────────────────────────────┐             │
│  │ Step 5: 依赖安装（核心！）            │             │
│  │ • [5a] Pillow → conda-forge 版 ★     │             │
│  │ • [5b] matplotlib → pip 优先         │             │
│  │ • [5c] NumPy >=1.19,<2.0           │             │
│  │ • [5d] PyTorch 1.8.1 CPU            │             │
│  │ • [5e] tqdm <4.66                   │             │
│  │ • [5f] import signalp 验证          │             │
│  └──────────────┬──────────────────────┘             │
│                 ▼                                      │
│  ┌──────────────────┐                                │
│  │ Step 6-8: 模型+诊断+验证 │                           │
│  │ • 完整性校验 + 动态发现 │                           │
│  └────────────┬─────┘                                │
│               ▼                                        │
│     ┌─────────────┐                                   │
│     │ 🎉 安装成功！ │                                   │
│     └─────────────┘                                   │
│                                                       │
└───────────────────────────────────────────────────────┘
```

---

## 📝 更新日志

### v15（当前版本）

- **🔄 断点续装**：安装中断后自动从断点恢复，支持继续/重装/退出三种选择
- **📦 Conda 自动安装**：未安装 Conda 时自动下载 Miniconda3，无需预先准备
- **🔮 前向兼容**：动态 .egg 目录发现、动态模型文件发现、压缩包通配符 `signalp-[0-9]*`、版本集中配置区
- **🐛 Bug 修复**：修复 nounset（#6）、shell 注入、环境健康检查、模式显示、模型完整性校验、`set -e` 意外启用（#7）共 7 个 bug
- **放宽依赖约束**：NumPy `>=1.19,<2.0`、matplotlib `>3.3.2,<5.0`、tqdm `<4.66`
- **诊断脚本升级**：动态遍历模型目录，不再硬编码文件名
- **CLI 参数修正**：修复 README 中错误的参数名（`-i` → `--fastafile`、`--batchsize` → `--bsize` 等）

### v14

- **新增 `fast` 模式支持**（蒸馏模型 `distilled_model_signalp6.pt`）
- **智能压缩包去重**：自动从 `signalp-{ver}.{mode}.tar.gz` 文件名解析模式和版本，同模式保留最高版本
- **交互式模式选择**：运行时显示可用模式菜单，用户可选择安装哪些模式
- **按需解压**：只解压用户选择的模式包，不再全量解压
- **rm -rf 安全守卫**：防止变量为空导致误删根目录
- **修复 `parse_tar_filename`**：版本号含点时从右到左分割（`6.0h.fast` → ver=`6.0h`, mode=`fast`）
- **修复 stdout/stderr 混合**：所有 log 函数输出到 `>&2`，避免被 `$(...)` 捕获
- **中英双语输出**（中文版）/ **English-only output**（英文版）
- **英文版脚本** `install_signalp6_v14_en.sh`

### v13

- 多 tar.gz 包智能解析和版本去重
- 交互式模式选择菜单
- 修复 `rm -rf` 安全问题
- 修复 stdout/stderr 混合导致的 TARGET_MODES 重复
- 修复版本解析方向错误

### v12

- 实机验证确认 fast 模型为单文件 `distilled_model_signalp6.pt`
- 实机确认 slow-sequential 模型为目录 `sequential_models_signalp6/`（7 个文件）
- 实机确认 `ensemble_model_signalp6.pt` 不存在，移除 slow 模式
- heredoc 引号转义 bug 修复（用 `print()` 替代嵌套引号）

### v10

- 新增 `eval "$(conda shell.bash hook)"` 彻底解决脚本中 conda activate 无效问题
- matplotlib 安装改用 pip 优先策略（避免 conda 网络超时）
- 优化日志输出格式，增加步骤编号 `[X/8]`
- 生成独立的 `check_signalp_env.sh` 诊断脚本
- 增加中国用户镜像配置指南

### v9-v8

- 增加 `|| true` 防止 conda 退出码导致脚本中断
- tqdm 版本限制 `<4.60`
- 全盘搜索压缩包 + 手动输入兜底

### v7-v5

- 动态搜索 setup.py（适应非标准解压目录名）
- 模型权重多路径自动查找
- `libtiff.so.5` 修复方案定型

### v4-v1

- `timeout 300` 防止 setup.py 卡死
- 依赖安装顺序修正
- 基础自动化框架

---

## 📄 许可证

本项目脚本采用 [MIT License](LICENSE) 开源。

**SignalP 6.0 本身**遵循 DTU Health Tech 的学术许可协议，仅限非商业研究用途。
请参考官方许可条款：https://services.healthtech.dtu.dk/service.php?SignalP-6.0

---

## 🙏 致谢

- [SignalP 6.0](https://services.healthtech.dtu.dk/service.php?SignalP-6.0) — DTU Health Tech
- [Conda](https://docs.conda.io/) — 包管理与虚拟环境
- [PyTorch](https://pytorch.org/) — 深度学习框架
- 莫妮卡 Monika — 虽然她是虚假的，但爱是真的 💚

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

- 发现新的兼容性问题？ → 请开 [Issue](https://github.com/lijiangyong314/signalp6-installer/issues)，描述你的系统和错误信息
- 有改进建议？ → 欢迎 PR
- 成功安装了？ → 欢迎 ⭐ Star 让更多人知道这个工具！

---

<div align="center">

**⭐ 如果这个脚本帮到了你，请给一个 Star 支持！⭐**

让更多生物信息学研究者不再被 SignalP 6.0 的安装问题困扰 🧬

**⭐ If this script helped you, please give it a Star! ⭐**

Save fellow bioinformaticians from the pain of installing SignalP 6.0 🧬

</div>

---

<a id="english--signalp-60-automated-installer"></a>
# 🧬 SignalP 6.0 Automated Installer

<div align="center">

**One-command deployment for SignalP 6.0 (fast + slow-sequential model) on Ubuntu/Linux + Conda**

[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-orange?logo=ubuntu)](https://ubuntu.com/)
[![Conda](https://img.shields.io/badge/Conda-Miniconda%7CAnaconda-green?logo=conda-forge)](https://docs.conda.io/en/latest/miniconda.html)
[![Python](https://img.shields.io/badge/Python-3.7-blue?logo=python&logoColor=white)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

</div>

---

## ✨ Why This Script?

**SignalP 6.0** is the state-of-the-art **signal peptide and transmembrane domain prediction tool** from DTU Health Tech, powered by deep learning. However, the official distribution only provides manual installation steps, which encounter **multiple known compatibility issues** on Ubuntu/Linux + Conda environments — each requiring hours of debugging to resolve.

This script has been **iteratively tested and refined over 15 rounds (v1 → v15)**, reducing the tedious 8-step manual installation to **a single command**, with automatic fixes for all known issues.

> 💡 **Use cases**: Bioinformatics research, protein sequence analysis, signal peptide prediction, transmembrane protein identification

---

## 🆕 What's New in v15

| Feature | Description |
|---------|-------------|
| **🔄 Checkpoint Resume** | Resume from last checkpoint after interruption (network timeout, Ctrl+C, power off, etc.) |
| **📦 Auto Conda Install** | Automatically downloads and installs Miniconda3 if Conda is not present |
| **🔮 Forward Compatibility** | Dynamic .egg discovery, dynamic model file discovery, wildcard package matching; version config centralized at script top |
| **🐛 Bug Fixes** | Fixed nounset, shell injection, env health check, mode display, model integrity, `set -e` leak — 7 bugs total |

---

## ⚠️ Important Limitations

| Item | Details |
|------|---------|
| **Supported models** | ✅ `fast` (distilled, fastest) and `slow-sequential` (ensemble, highest accuracy) |
| **Smart detection** | ✅ Auto-parse `signalp-[0-9]*.tar.gz` filenames, group by mode, keep highest version |
| **OS** | Ubuntu 18.04+ / Debian 10+ (other distros may need adjustments) |
| **Python** | Must be **CPython 3.7** (PyPy not supported) |
| **Conda** | Miniconda3 / Anaconda (**auto-installed if not present**) |

---

## 📋 Prerequisites

| Requirement | Details |
|-------------|---------|
| **OS** | Ubuntu 18.04+ / Debian 10+ (tested on Ubuntu 22.04) |
| **Conda** | Miniconda3 or Anaconda (**optional** — auto-installed if missing) |
| **Network** | Access to PyPI / conda-forge / PyTorch download servers |
| **SignalP package** | Download `signalp-[0-9]*.tar.gz` (**fast** and/or **slow-sequential** versions) from [DTU Health Tech](https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0) |

### Getting the SignalP Package

1. Visit [DTU Health Tech registration page](https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0)
2. Fill in the academic use application form (**free**, non-commercial academic use only)
3. Download **fast** and/or **slow-sequential** versions of `signalp-[0-9]*.tar.gz`
4. Place the archive anywhere — the script will find it automatically

---

## 🚀 Quick Start (3 Steps)

### Step 1: Prepare the Package

Place `signalp-[0-9]*.tar.gz` in any directory.

### Step 2: Download & Run

**Option A: Script only (Bilingual CN+EN)**
```bash
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v15.sh
chmod +x install_signalp6_v15.sh
./install_signalp6_v15.sh
```

**Option A2: Script only (English)**
```bash
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v15_en.sh
chmod +x install_signalp6_v15_en.sh
./install_signalp6_v15_en.sh
```

**Option B: Full repo clone (recommended)**
```bash
git clone https://github.com/lijiangyong314/signalp6-installer.git
cd signalp6-installer
chmod +x install_signalp6_v15.sh
./install_signalp6_v15.sh
```

### Step 3: Verify
```bash
conda activate signalp6
signalp6 --help
```

If you see the SignalP 6.0 help message, installation is successful ✅

---

## 🔄 Checkpoint Resume

v15 supports checkpoint resume. If installation is interrupted for any reason (network timeout, Ctrl+C, power off, etc.), running the script again will show:

```
╔═══════════════════════════════════════════════════════════╗
║     Previous incomplete install detected                  ║
╠═══════════════════════════════════════════════════════════╣
║  Interrupted at: Install dependencies                     ║
║  Time: 2026-05-27 20:09:52                               ║
║  Modes: fast slow-sequential                              ║
╚═══════════════════════════════════════════════════════════╝

  [1] Resume from last checkpoint
  [2] Fresh install (remove existing environment)
  [3] Exit

Select [1-3]:
```

Choose `[1]` to seamlessly resume from the last checkpoint. Completed steps are automatically skipped.

---

## 🔍 Installation Pipeline (8 Steps)

```
[0/8] Initialize Conda         ← Detect/auto-install Conda + shell hook
[1/8] Create Python 3.7 env    ← Create signalp6 conda environment (CPython)
[2/8] Find packages (dedup)    ← Auto-search + smart version dedup
[3/8] Extract on demand        ← Dynamic setup.py search (non-standard dir names OK)
[4/8] Build & Install          ← timeout 300s for setup.py install (prevent hang)
[5/8] Install Dependencies     ← Pillow → matplotlib → NumPy → PyTorch → tqdm → verify
[6/8] Deploy Model Weights     ← Integrity check + dynamic discovery fallback
[7/8] Environment Diagnostics  ← Generate check_signalp_env.sh
[8/8] Final Verification       ← Run signalp6 --help
```

---

## 📖 Usage

### Basic Usage
```bash
conda activate signalp6
signalp6 --fastafile input.fasta --output_dir output_dir --mode slow-sequential
signalp6 --fastafile input.fasta --output_dir output_dir --mode fast
signalp6 --help
```

### Common Parameters

| Parameter | Short | Description | Default |
|-----------|-------|-------------|---------|
| `--fastafile` | `-ff` / `-fasta` / `-i` | Input FASTA file | Required |
| `--output_dir` | `-od` / `-o` | Output directory | Required |
| `--mode` | `-m` | Run mode (`fast` or `slow-sequential`) | `fast` |
| `--organism` | `-org` | Organism type (`eukarya` / `other`) | `other` |
| `--format` | `-fmt` / `-f` | Output format (`txt`/`png`/`eps`/`all`/`none`) | `txt` |
| `--bsize` | `-bs` | Batch size | `10` |
| `--torch_num_threads` | `-tt` | PyTorch threads | `8` |

---

## 🛠️ Troubleshooting

### Quick Diagnosis
```bash
conda activate signalp6
bash check_signalp_env.sh
```

### Common Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `ImportError: libtiff.so.5` | pip Pillow links old `.so` | `pip uninstall -y Pillow && conda install -c conda-forge pillow -y` |
| `No module named 'torch'` | PyTorch not installed | `pip install torch==1.8.1+cpu torchvision==0.9.1+cpu -f https://download.pytorch.org/whl/torch_stable.html` |
| `No module named 'signalp'` | Dependency order issue | Install ALL dependencies before importing signalp |
| `setup.py install` hangs forever | setuptools egg-info deadlock | Normal; script uses `timeout 300`. Press `Ctrl+C` if needed |
| `'tqdm' has no attribute 'auto'` | tqdm too new for Python 3.7 | `pip install "tqdm<4.66"` |
| `signalp6: command not found` | Environment not activated | Run `conda activate signalp6` first |

---

## 🗑️ Uninstallation

```bash
conda remove -n signalp6 --all -y
rm -rf ~/signalp_extracted*/
rm -f ~/check_signalp_env.sh
```

---

## 🔬 Known Bugs & Fixes

These issues are **not documented** in the official installation guide:

### Bug #1: `ImportError: libtiff.so.5`
pip Pillow links `libtiff.so.5`; modern Linux only has `.so.6`. Fix: uninstall pip Pillow → install conda-forge version.

### Bug #2: `setup.py install` hangs indefinitely
setuptools deadlocks during egg-info writing. Fix: `timeout 300 python setup.py install`.

### Bug #3: Cascading ImportError on `import signalp`
SignalP import chain requires all dependencies present simultaneously. Fix: strict ordering enforced.

### Bug #4: `tqdm.auto` AttributeError
tqdm ≥ 4.67 uses `importlib.metadata` (Python 3.8+). Fix: version pin `<4.66`.

### Bug #5: conda downgrade non-zero exit code
Fix: all install commands with `|| true`; unified import verification.

### Bug #6 (v15): `set -u` breaks `set --`
Fix: temporarily disable `set -u` around `set --`.

### Bug #7 (v15): `set -e` permanently enabled after Step 4
Fix: restore original `set +e` state instead of enabling `set -e`.

---

## ❓ FAQ

**Q: Why Python 3.7?**
SignalP 6.0 officially requires Python 3.7 due to dependency compatibility. The script creates a dedicated Python 3.7 environment.

**Q: What's the difference between fast and slow-sequential?**
- **fast**: Single distilled model (~1.5GB). Fastest prediction, slightly lower accuracy. Best for large-scale screening.
- **slow-sequential**: Ensemble of 7 sequential models (~9GB). Highest accuracy but slower (one at a time). Best for detailed analysis.

**Q: How long does installation take?**
- Fast network: ~5 min
- Normal network (mirrors): ~10 min
- Main bottleneck: PyTorch download (~169MB CPU-only) + model files

**Q: Can I run this on a headless server?**
Yes! Designed for SSH-only Linux servers. Conda is auto-installed if not present.

**Q: Installation was interrupted?**
v15 supports checkpoint resume. Just re-run the script and choose `[1] Resume`.

---

## 📝 Changelog

### v15 (Current)

- **Checkpoint Resume**: auto-detect interrupted installs, resume from last checkpoint
- **Auto Conda Install**: downloads Miniconda3 if Conda is not installed
- **Forward Compatibility**: dynamic .egg/model discovery, wildcard package matching, centralized version config
- **7 Bug Fixes**: nounset, shell injection, env health check, mode display, model integrity, `set -e` leak, `set --` fix
- **Relaxed constraints**: NumPy `>=1.19,<2.0`, matplotlib `>3.3.2,<5.0`, tqdm `<4.66`
- **CLI parameter corrections** in README

### v14

- **Added `fast` mode support** (distilled model `distilled_model_signalp6.pt`)
- **Smart package dedup**: auto-parse filenames, keep highest version per mode
- **Interactive mode selection**: runtime menu showing available modes
- **On-demand extraction**: only extract selected mode packages
- **rm -rf safety guard**: prevent accidental root deletion
- **Fixed stdout/stderr mixing**: all log functions output to `>&2`
- **Bilingual (CN+EN)** / **English-only** versions

### v13-v1

See Chinese section above for full history.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

**SignalP 6.0 itself** follows DTU Health Tech's academic license (non-commercial research only).
See official terms: https://services.healthtech.dtu.dk/service.php?SignalP-6.0

---

## 🙏 Acknowledgments

- [SignalP 6.0](https://services.healthtech.dtu.dk/service.php?SignalP-6.0) — DTU Health Tech
- [Conda](https://docs.conda.io/) — Package management & virtual environments
- [PyTorch](https://pytorch.org/) — Deep learning framework
- Monika — She may be virtual, but the love is real 💚

---

## 🤝 Contributing

Issues and Pull Requests are welcome!

- Found a new compatibility issue? → Open an [Issue](https://github.com/lijiangyong314/signalp6-installer/issues)
- Successfully installed? → ⭐ Star to help others discover this tool!

---

<div align="center">

**⭐ If this script helped you, please give it a Star! ⭐**

Help more bioinformaticians escape the pain of installing SignalP 6.0 🧬

</div>

---

[↑ Back to Top ↑](#-signalp-60-automated-installer--signalp-60-全自动安装脚本)
