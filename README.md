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

本脚本经过 **14 轮迭代验证**（v1 → v14），将繁琐的 8 步手动安装简化为**一条命令**，并自动修复了所有已知故障点。v14 新增 **fast + slow-sequential 双模式支持**、智能压缩包去重、交互式模式选择等功能。

> 💡 **适用场景**：生物信息学研究、蛋白质序列分析、信号肽预测、跨膜蛋白鉴定

---

## ⚠️ 重要限制

| 项目 | 说明 |
|------|------|
| **支持模型** | ✅ `fast`（蒸馏模型，速度最快）和 `slow-sequential`（顺序模型，最高精度） |
| **智能识别** | ✅ 自动解析 `signalp-6*.tar.gz` 文件名，按模式分组并保留最高版本 |
| **操作系统** | Ubuntu 18.04+ / Debian 10+（其他 Linux 发行版可能需调整） |
| **Python** | 必须为 **CPython 3.7**（PyPy 不支持） |

> 📌 脚本会自动扫描目录中的所有 SignalP 压缩包，交互式让你选择安装哪些模式。如果同模式有多个版本，自动保留最高版本。

---

## 📋 前置条件

| 条件 | 要求 | 说明 |
|------|------|------|
| **操作系统** | Ubuntu 18.04+ / Debian 10+ | 已测试 Ubuntu 22.04 |
| **Conda** | [Miniconda3](https://docs.conda.io/en/latest/miniconda.html) 或 Anaconda | 必须预先安装 |
| **网络连接** | 可访问 PyPI / conda-forge / PyTorch 下载源 | 🇨🇳 中国用户建议配置镜像（见下方） |
| **SignalP 安装包** | 从 [DTU Health Tech](https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0) 下载 `signalp-6*.tar.gz` | **选择 slow 版本** |

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
3. 收到下载链接后，下载 `signalp-6*.tar.gz`（支持 **fast** 和 **slow-sequential** 版本，可同时下载多个）
4. 将压缩包放置于以下任一目录：
   - `~/Desktop` 或 `~/桌面`
   - `~/Downloads` 或 `~/下载`
   - 脚本所在目录
   - **任意位置**（脚本也会自动全盘搜索）

> 📌 **学术许可提醒**：SignalP 6.0 仅限非商业学术研究用途，请遵守 DTU 的许可协议。

---

## 🚀 快速开始（3 步搞定）

### Step 1：准备安装包

将下载的 `signalp-6*.tar.gz` 放入上述目录之一。

### Step 2：下载并运行脚本

**方式 A：仅下载脚本（中文双语版 / Bilingual）**

```bash
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v14.sh
chmod +x install_signalp6_v14.sh
./install_signalp6_v14.sh
```

**方式 A2：仅下载脚本（英文版 / English）**

```bash
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v14_en.sh
chmod +x install_signalp6_v14_en.sh
./install_signalp6_v14_en.sh
```

**方式 B：克隆完整仓库（含 README 文档 + 脚本，推荐）**

```bash
git clone https://github.com/lijiangyong314/signalp6-installer.git
cd signalp6-installer
chmod +x install_signalp6_v14.sh
./install_signalp6_v14.sh
```

> 💡 **推荐方式 B**：一条命令拿到脚本 + 完整文档，以后 `git pull` 还能自动获取更新。

### Step 3：验证安装

```bash
conda activate signalp6
signalp6 --help
```

成功的话会显示 SignalP 6.0 的帮助信息。看到 `🎉 安装成功！` 的提示即表示一切就绪 ✅

---

## 🔍 脚本执行流程详解

脚本共分为 **8 个步骤**，每步都有详细的日志输出和错误处理：

```
[0/8] 初始化 Conda          ← 检测 Conda 路径 + 激活 shell hook
[1/8] 创建 Python 3.7 环境   ← 创建 signalp6 conda 环境（CPython）
[2/8] 定位 signalp-6*.tar.gz ← 自动搜索常用目录 + 全盘扫描 + 手动输入兜底
[3/8] 解压安装包            ← 动态搜索 setup.py（兼容非标准目录名）
[4/8] 编译安装              ← timeout 300s 限时执行 setup.py install
[5/8] 安装所有依赖           ← Pillow → matplotlib → NumPy → PyTorch → tqdm
[6/8] 部署模型权重          ← 自动查找 sequential_models_signalp6 目录
[7/8] 环境诊断              ← 生成 check_signalp_env.sh 诊断脚本
[8/8] 最终验证             ← 执行 signalp6 --help
```

### 各步骤关键要点

| 步骤 | 功能 | 关键技术细节 |
|:----:|------|-------------|
| **0** | 初始化 Conda | 使用 `eval "$(conda shell.bash hook)"` 解决 non-interactive shell 中 activate 无效的问题 |
| **1** | 创建环境 | 强制检查 Python 实现为 CPython（PyPy 不兼容 PyTorch） |
| **2** | 定位压缩包 | 多级搜索策略：常用目录 → 工作目录 → `/home` 全盘搜索（限时 30 秒）→ 手动输入 |
| **3** | 解压 | 用 `find -name setup.py` 动态定位源码目录，不硬编码路径 |
| **4** | 编译安装 | `timeout 300` 防卡死 + `set +e` 防 timeout 退出码导致脚本中断 |
| **5a** | **Pillow 修复** | **核心修复**：卸载 pip 版 Pillow → 改装 conda-forge 版，彻底解决 `libtiff.so.5` 缺失问题 |
| **5b** | matplotlib | 优先 pip 安装（走国内镜像），回退 conda |
| **5c** | NumPy | 版本限制 `<2.0` 以兼容 Python 3.7 |
| **5d** | PyTorch | 优先 pip 安装 1.8.1+cpu（CPU only），所有命令加 `\|\| true` 防退出码异常 |
| **5e** | tqdm | 版本限制 `<4.60`（4.67+ 使用了 Python 3.8+ 的 `importlib.metadata`） |
| **5f** | import 验证 | 所有依赖就绪后才尝试 `import signalp`，失败时逐项提示缺失项 |
| **6** | 模型权重 | 多路径搜索解压包内、桌面、Home 目录等位置 |
| **7** | 诊断 | 生成独立可复用的 `check_signalp_env.sh` 脚本 |
| **8** | 最终验证 | 用 `conda run` 执行避免 PATH 问题 |

---

## 📖 使用方法

### 基本用法

```bash
# 激活环境
conda activate signalp6

# 运行预测（基本参数）
signalp6 -i input.fasta -o output_dir -m slow-sequential

# 查看完整帮助
signalp6 --help
```

### 常用参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-i` | 输入 FASTA 文件路径 | `-i proteins.fasta` |
| `-o` | 输出目录 | `-o results/` |
| `-m` | 运行模式（`fast` 或 `slow-sequential`） | `-m fast` 或 `-m slow-sequential` |
| `--organism` | 生物体类型（euk/gram+/gram-/meta） | `--organism euk` |
| `--format` | 输出格式（short/long/json/csv/tsv） | `--format json` |
| `--batchsize` | 批处理大小（默认 512） | `--batchsize 256` |
| `--cpu` | CPU 线程数 | `--cpu 4` |

### 输出文件说明

运行完成后，输出目录中会包含以下文件：

| 文件 | 说明 |
|------|------|
| `predictions.json` | JSON 格式的预测结果（含置信度分数） |
| `summary.txt` | 摘要报告 |
| `output.gff3` | GFF3 格式注释文件 |
| `output.fasta` | 处理后的序列文件 |

### 示例：分析真核生物蛋白质（slow-sequential 模式）

```bash
conda activate signalp6

signalp6 \
  -i my_proteins.fasta \
  -o signalp_results \
  -m slow-sequential \
  --organism euk \
  --format long \
  --cpu 4
```

### 示例：快速预测（fast 模式）

```bash
conda activate signalp6

signalp6 \
  -i my_proteins.fasta \
  -o signalp_results \
  -m fast \
  --format json
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
--- SignalP 6.0 诊断报告 ---
1. Python 环境：Python 3.7.16
2. 核心依赖：
   NumPy:      1.24.4 ✅
   PyTorch:    1.8.1+cpu ✅
   Pillow:     9.4.0 ✅
   Matplotlib: 3.7.5 ✅
   tqdm:       OK ✅
3. SignalP 状态：
   ✅ import signalp 成功: .../site-packages/signalp6-6.0+h-py3.7.egg/signalp/__init__.py
   ✅ 模型目录存在: .../model_weights/sequential_models_signalp6
4. signalp6 命令：
   ✅ signalp6 在 PATH
--- 诊断结束 ---
```

### 常见问题速查表

| 错误信息 | 原因 | 解决方案 |
|----------|------|---------|
| `ImportError: libtiff.so.5` | pip 版 Pillow 链接旧版 .so 文件 | `pip uninstall -y Pillow && conda install -c conda-forge pillow -y` |
| `No module named 'torch'` | PyTorch 未正确安装 | `pip install torch==1.8.1+cpu torchvision==0.9.1+cpu -f https://download.pytorch.org/whl/torch_stable.html` |
| `No module named 'signalp'` | 依赖安装顺序错误 | **必须**先装完所有依赖再 import signalp（重新运行脚本的第 5 步即可） |
| `setup.py install` 卡住不退出 | setuptools egg 写入过程卡死 | 正常现象，脚本已用 `timeout 300` 自动处理；也可按 `Ctrl+C` 手动终止 |
| `'tqdm' has no attribute 'auto'` | tqdm 版本过高不兼容 Python 3.7 | `pip install "tqdm<4.60"` |
| `ModuleNotFoundError: No module named 'matplotlib'` | matplotlib 未安装 | `pip install "matplotlib>3.3.2,<4.0"` |
| `conda activate` 在脚本中无效 | non-interactive shell 限制 | 使用 `eval "$(conda shell.bash hook)"` 替代直接 source |
| conda 网络超时 | 无法连接 repo.anaconda.com | 配置清华镜像（见上方「中国用户网络优化」） |
| `找不到 signalp-6*.tar.gz` | 压缩包不在搜索路径内 | 将压缩包移到 `~/Desktop`/`~/Downloads`，或脚本会提示手动输入路径 |
| 模型权重缺失 | 解压包内无模型目录 | 手动复制：`cp -r <source>/sequential_models_signalp6 $SIGNALP_DIR/model_weights/` |
| `signalp6: command not found` | 未激活 conda 环境 | 先执行 `conda activate signalp6` |
| `Python implementation is PyPy` | 环境使用了 PyPy | 删除重建环境：`conda remove -n signalp6 --all -y && ./install_signalp6_v14.sh` |

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
pip install "numpy>=1.19,<1.25"
pip install "matplotlib>3.3.2,<4.0"
pip install "tqdm<4.60"

# 5. 验证
python -c "import signalp; print('✅ SignalP 6.0 就绪')"

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

**修复**：版本锁定 `pip install "tqdm<4.60"`。

### Bug #5：conda 降级操作非零退出码

**现象**：执行 `conda install pytorch==1.8.1 cpuonly -y` 时脚本意外退出。

**根因**：当 conda 需要降级某个包时，返回非零退出码，被 `set -e` 捕获后导致整个脚本终止。

**修复**：所有 conda/pip 安装命令末尾加 `|| true`，最后统一做 import 验证。

---

## 🗑️ 卸载方法

```bash
# 1. 删除 conda 环境（包含所有已安装的依赖）
conda remove -n signalp6 --all -y

# 2. （可选）删除脚本生成的临时文件
rm -rf ~/signalp_extracted/      # 解压临时目录（如果在 Home 下）
rm -f ~/check_signalp_env.sh     # 诊断脚本

# 3. （可选）从 conda 环境列表确认已清理
conda env list | grep signalp    # 应该无输出
```

---

## ❓ FAQ（常见问题）

### Q1：为什么必须是 Python 3.7？
SignalP 6.0 官方要求 Python 3.7，因为其依赖的某些库（特别是早期版本的 torch 和相关绑定）对更高版本 Python 存在兼容性问题。脚本强制创建 Python 3.7 环境。

### Q2：为什么只支持 slow-sequential 模型？
官方提供的 slow 版压缩包中仅包含 `sequential_models_signalp6` 目录。fast 模型的权重文件结构不同，且未在公开分发包中提供。如果你有 fast 模型文件，可以手动修改脚本中的模型路径。

### Q3：安装大概需要多久？
取决于网络速度：
- **快速网络**（直连 PyPI）：~5 分钟
- **普通网络**（使用镜像）：~10 分钟
- **较慢网络**：~15-20 分钟
- 主要耗时在下载 PyTorch (~2GB) 和编译安装阶段

### Q4：可以在服务器上运行吗？
可以！本脚本专为无 GUI 的 Linux 服务器设计。只需确保：
1. 服务器已安装 Miniconda/Anaconda
2. 将 `signalp-6*.tar.gz` 上传到服务器的任意目录
3. SSH 登录后运行脚本即可

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
# 安装 Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh
ENV PATH="/opt/conda/bin:$PATH"
# 复制并运行安装脚本
COPY install_signalp6_v14.sh /opt/
COPY signalp-6*.tar.gz /opt/
RUN cd /opt && bash install_signalp6_v14.sh
```

### Q7：脚本会修改系统环境吗？
不会。脚本的所有操作都在 conda 虚拟环境 `signalp6` 内进行，不涉及系统 Python 或全局包管理。唯一可能的外部操作是 `sudo apt-get install libtiff5`（仅在 Pillow 安装失败时的兜底措施，且需要用户确认）。

---

## 📊 安装流程图

```
┌───────────────────────────────────────────────────────┐
│            SignalP 6.0 自动安装流程                    │
├───────────────────────────────────────────────────────┤
│                                                       │
│  ┌─────────┐                                         │
│  │ 准备工作  │  Conda + signalp-6*.tar.gz             │
│  └────┬────┘                                         │
│       ▼                                               │
│  ┌─────────────┐                                     │
│  │ 运行脚本     │  ./install_signalp6_v14.sh        │
│  └────┬────────┘                                     │
│       ▼                                               │
│  ┌─────────────────────────────────────┐             │
│  │ Step 0-4: 环境准备 & 编译安装         │             │
│  │ • 创建 signalp6 (Python 3.7) 环境     │             │
│  │ • 搜索 & 解压 tar.gz                 │             │
│  │ • timeout 300 setup.py install       │             │
│  └──────────────┬──────────────────────┘             │
│                 ▼                                      │
│  ┌─────────────────────────────────────┐             │
│  │ Step 5: 依赖安装（核心！）            │             │
│  │ • [5a] Pillow → conda-forge 版 ★     │             │
│  │ • [5b] matplotlib → pip 优先         │             │
│  │ • [5c] NumPy <2.0                   │             │
│  │ • [5d] PyTorch 1.8.1 CPU            │             │
│  │ • [5e] tqdm <4.60                   │             │
│  │ • [5f] import signalp 验证          │             │
│  └──────────────┬──────────────────────┘             │
│                 ▼                                      │
│  ┌──────────────────┐                                │
│  │ Step 6-8: 模型+诊断+验证 │                           │
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

### v14（当前版本）

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

This script has been **iteratively tested and refined over 14 rounds (v1 → v14)**, reducing the tedious 8-step manual installation to **a single command**, with automatic fixes for all known issues. v14 adds **fast + slow-sequential dual-mode support**, smart package dedup, and interactive mode selection.

> 💡 **Use cases**: Bioinformatics research, protein sequence analysis, signal peptide prediction, transmembrane protein identification

---

## ⚠️ Important Limitations

| Item | Details |
|------|---------|
| **Supported models** | ✅ `fast` (distilled, fastest) and `slow-sequential` (ensemble, highest accuracy) |
| **Smart detection** | ✅ Auto-parse `signalp-6*.tar.gz` filenames, group by mode, keep highest version |
| **OS** | Ubuntu 18.04+ / Debian 10+ (other distros may need adjustments) |
| **Python** | Must be **CPython 3.7** (PyPy not supported) |

---

## 📋 Prerequisites

| Requirement | Details |
|-------------|---------|
| **OS** | Ubuntu 18.04+ / Debian 10+ (tested on Ubuntu 22.04) |
| **Conda** | [Miniconda3](https://docs.conda.io/en/latest/miniconda.html) or Anaconda pre-installed |
| **Network** | Access to PyPI / conda-forge / PyTorch download servers |
| **SignalP package** | Download `signalp-6*.tar.gz` (**slow version**) from [DTU Health Tech](https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0) |

### Getting the SignalP Package

1. Visit [DTU Health Tech registration page](https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0)
2. Fill in the academic use application form (**free**, non-commercial academic use only)
3. Download the **slow version** `signalp-6*.tar.gz` after receiving the download link
4. Place the archive in any of these directories: `~/Desktop`, `~/Downloads`, script directory, or anywhere (the script will search automatically)

---

## 🚀 Quick Start (3 Steps)

### Step 1: Prepare the Package

Place `signalp-6*.tar.gz` in one of the directories listed above.

### Step 2: Download & Run

**Option A: Script only**
```bash
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v14.sh
chmod +x install_signalp6_v14.sh
./install_signalp6_v14.sh
```

**Option B: Full repo clone (recommended)**
```bash
git clone https://github.com/lijiangyong314/signalp6-installer.git
cd signalp6-installer
chmod +x install_signalp6_v14.sh
./install_signalp6_v14.sh
```

### Step 3: Verify
```bash
conda activate signalp6
signalp6 --help
```

If you see the SignalP 6.0 help message, installation is successful ✅

---

## 🔍 Installation Pipeline (8 Steps)

```
[0/8] Initialize Conda         ← Detect Conda path + activate shell hook
[1/8] Create Python 3.7 env    ← Create signalp6 conda environment (CPython)
[2/8] Locate signalp-6*.tar.gz ← Auto-search common dirs + full scan + manual fallback
[3/8] Extract                  ← Dynamic setup.py search (non-standard dir names OK)
[4/8] Build & Install          ← timeout 300s for setup.py install (prevent hang)
[5/8] Install Dependencies     ← Pillow → matplotlib → NumPy → PyTorch → tqdm
[6/8] Deploy Model Weights     ← Auto-find sequential_models_signalp6 directory
[7/8] Environment Diagnostics  ← Generate check_signalp_env.sh
[8/8] Final Verification       ← Run signalp6 --help
```

### Key Technical Decisions

| Step | What | Key Detail |
|:----:|------|------------|
| **0** | Init Conda | `eval "$(conda shell.bash hook)"` fixes non-interactive shell activate |
| **1** | Create env | Enforce CPython check (PyPy incompatible with PyTorch) |
| **2** | Find tarball | Multi-level search: common dirs → workdir → `/home` scan (30s limit) → manual input |
| **3** | Extract | `find -name setup.py` dynamic locate, no hardcoded paths |
| **4** | Build | `timeout 300` anti-hang + `set +e` prevent exit code kill |
| **5a** | **Pillow fix** | **Core fix**: uninstall pip Pillow → install conda-forge version (`libtiff.so.5`) |
| **5b** | matplotlib | pip first (faster), fallback to conda |
| **5c** | NumPy | Pin `<2.0` for Python 3.7 compat |
| **5d** | PyTorch | pip install 1.8.1+cpu (CPU only), all commands with `\|\| true` |
| **5e** | tqdm | Pin `<4.60` (4.67+ uses `importlib.metadata`, a Py 3.8+ feature) |
| **5f** | Import verify | Only attempt `import signalp` after ALL dependencies are ready |
| **6** | Model weights | Multi-path search: extracted pkg, Desktop, Home, etc. |
| **7** | Diagnostics | Generate standalone reusable diagnostic script |
| **8** | Verify | Use `conda run` to avoid PATH issues |

---

## 📖 Usage

### Basic Usage
```bash
conda activate signalp6
signalp6 -i input.fasta -o output_dir -m slow-sequential
signalp6 --help
```

### Common Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-i` | Input FASTA file | `-i proteins.fasta` |
| `-o` | Output directory | `-o results/` |
| `-m` | Run mode (`fast` or `slow-sequential`) | `-m fast` or `-m slow-sequential` |
| `--organism` | Organism type (euk/gram+/gram-/meta) | `--organism euk` |
| `--format` | Output format (short/long/json/csv/tsv) | `--format json` |
| `--batchsize` | Batch size (default 512) | `--batchsize 256` |
| `--cpu` | Number of CPU threads | `--cpu 4` |

### Example: Eukaryotic Protein Analysis
```bash
conda activate signalp6

signalp6 \
  -i my_proteins.fasta \
  -o signalp_results \
  -m slow-sequential \
  --organism euk \
  --format long \
  --cpu 4
```

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
| `No module named 'signalp'` | Dependency order issue | Install ALL dependencies before importing signalp (re-run Step 5) |
| `setup.py install` hangs forever | setuptools egg-info deadlock | Normal; script uses `timeout 300`. Press `Ctrl+C` if needed |
| `'tqdm' has no attribute 'auto'` | tqdm too new for Python 3.7 | `pip install "tqdm<4.60"` |
| `ModuleNotFoundError: No module named 'matplotlib'` | matplotlib missing | `pip install "matplotlib>3.3.2,<4.0"` |
| `conda activate` fails in script | Non-interactive shell | Use `eval "$(conda shell.bash hook)"` instead of sourcing |
| conda network timeout | Can't reach repo.anaconda.com | Configure mirrors (see Chinese user guide above) |
| `signalp6: command not found` | Environment not activated | Run `conda activate signalp6` first |

---

## 🗑️ Uninstallation

```bash
# Remove conda environment (includes all dependencies)
conda remove -n signalp6 --all -y

# Optional: clean up generated files
rm -rf ~/signalp_extracted/
rm -f ~/check_signalp_env.sh

# Confirm cleanup
conda env list | grep signalp   # should return nothing
```

---

## 🔬 Known Bugs & Fixes

These issues are **not documented** in the official installation guide:

### Bug #1: `ImportError: libtiff.so.5`

**Root cause**: pip-installed Pillow dynamically links `libtiff.so.5`, but modern Linux (Ubuntu 22.04+) only ships `libtiff.so.6`.

**Fix**: Uninstall pip Pillow → install via conda-forge (ships compatible `.so` links).

### Bug #2: `setup.py install` hangs indefinitely

**Root cause**: setuptools deadlocks during egg-info writing on certain setuptools + Python 3.7 combinations.

**Fix**: `timeout 300 python setup.py install` (exit code 124 = killed by timeout, but installation is complete).

### Bug #3: Cascading ImportError on `import signalp`

**Root cause**: SignalP import chain: `signalp → predict → torch` and `signalp → plot → matplotlib → PIL`. Any missing link causes failure.

**Fix**: Script enforces strict ordering: install ALL dependencies → then verify import.

### Bug #4: `tqdm.auto` AttributeError

**Root cause**: tqdm ≥ 4.67 uses `importlib.metadata` (Python 3.8+ feature).

**Fix**: Version pin `"tqdm<4.60"`.

### Bug #5: conda downgrade non-zero exit code

**Root cause**: conda returns non-zero when downgrading packages; caught by `set -e` kills the entire script.

**Fix**: All install commands appended with `|| true`; unified verification at end.

---

## ❓ FAQ

**Q: Why Python 3.7?**
SignalP 6.0 officially requires Python 3.7 due to dependency compatibility (especially early PyTorch versions). The script creates a dedicated Python 3.7 environment.

**Q: What's the difference between fast and slow-sequential?**
- **fast**: Uses a single distilled model (`distilled_model_signalp6.pt`, ~400MB). Fastest prediction speed, slightly lower accuracy. Best for large-scale screening.
- **slow-sequential**: Uses an ensemble of 7 sequential models (~2GB). Highest accuracy but slower (processes one sequence at a time). Best for detailed analysis.

Both modes can be installed simultaneously. The script detects which packages you have and lets you choose interactively.

**Q: How long does installation take?**
- Fast network: ~5 min
- Normal network (mirrors): ~10 min
- Slow network: ~15-20 min
- Main bottleneck: PyTorch download (~2GB CPU-only)

**Q: Can I run this on a headless server?**
Yes! Designed for SSH-only Linux servers. Just upload the tarball and run.

**Q: How do I verify full success?**
```bash
conda activate signalp6
python -c "import signalp, torch, PIL, matplotlib; print('All imports OK')"
signalp6 --help
```

---

## 📝 Changelog

### v14 (Current)

- **Added `fast` mode support** (distilled model `distilled_model_signalp6.pt`)
- **Smart package dedup**: auto-parse `signalp-{ver}.{mode}.tar.gz` filenames, keep highest version per mode
- **Interactive mode selection**: runtime menu showing available modes
- **On-demand extraction**: only extract selected mode packages
- **rm -rf safety guard**: prevent accidental root deletion from empty variables
- **Fixed `parse_tar_filename`**: right-to-left split for version numbers with dots
- **Fixed stdout/stderr mixing**: all log functions output to `>&2`
- **Bilingual output (CN+EN)** / **English-only version** (`install_signalp6_v14_en.sh`)

### v13

- Multi-tarball smart parsing and version dedup
- Interactive mode selection menu
- Fixed `rm -rf` safety issue
- Fixed stdout/stderr mixing causing TARGET_MODES duplication
- Fixed version parsing direction

### v12

- Real-machine validated: fast model = single file `distilled_model_signalp6.pt`
- Real-machine validated: slow-sequential = directory `sequential_models_signalp6/` (7 files)
- Confirmed `ensemble_model_signalp6.pt` doesn't exist, removed slow mode
- Fixed heredoc quote escaping bug

### v10
- Added `eval "$(conda shell.bash hook)"` for reliable conda activation in scripts
- matplotlib: pip-first strategy (avoid conda timeout)
- Improved logging with step counters `[X/8]`
- Standalone `check_signalp_env.sh` diagnostic script
- Mirror configuration guide for Chinese users

### v9-v8
- `|| true` guards against conda exit codes killing script
- tqdm version pin `<4.60`
- Full-disk tarball search + manual input fallback

### v7-v5
- Dynamic `setup.py` search (non-standard extract dir names)
- Multi-path model weight auto-discovery
- `libtiff.so.5` fix finalized

### v4-v1
- `timeout 300` for setup.py anti-hang
- Dependency order correction
- Basic automation framework

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

---

## 🤝 Contributing

Issues and Pull Requests are welcome!

- Found a new compatibility issue? → Open an [Issue](https://github.com/lijiangyong314/signalp6-installer/issues) with your system details and error log
- Improvement ideas? → PRs welcome
- Successfully installed? → ⭐ Star to help others discover this tool!

---

<div align="center">

**⭐ If this script helped you, please give it a Star! ⭐**

Help more bioinformaticians escape the pain of installing SignalP 6.0 🧬

</div>

---

[↑ Back to Top ↑](#-signalp-60-automated-installer--signalp-60-全自动安装脚本)
