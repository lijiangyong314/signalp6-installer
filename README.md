# 🧬 SignalP 6.0 全自动安装脚本

<div align="center">

**一键部署 SignalP 6.0（slow-sequential 模型）**

[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-orange?logo=ubuntu)](https://ubuntu.com/)
[![Conda](https://img.shields.io/badge/Conda-Miniconda%7CAnaconda-green?logo=conda-forge)](https://docs.conda.io/en/latest/miniconda.html)
[![Python](https://img.shields.io/badge/Python-3.7-blue?logo=python&logoColor=white)](https://www.python.org/)

[English](#english) | 简体中文

</div>

---

## ✨ 为什么需要这个脚本？

SignalP 6.0 是 DTU Health Tech 开发的**信号肽与跨膜区域预测工具**，基于深度学习，是目前该领域最先进的工具之一。但官方只提供了手动安装步骤，在 Ubuntu/Linux + Conda 环境下存在**多个已知的兼容性问题**，手动排查非常耗时。

本脚本经过 **10 轮迭代验证**（v1 → v10），将繁琐的 8 步手动安装简化为**一条命令**，并自动修复了所有已知故障点。

> 💡 **适用场景**：生物信息学研究、蛋白质序列分析、信号肽预测、跨膜蛋白鉴定

---

## ⚠️ 重要限制

| 项目 | 说明 |
|------|------|
| **支持模型** | ✅ 仅支持 `slow-sequential` 预训练模型 |
| **不支持** | ❌ `fast-sequential` 模型（所需模型文件未包含在官方 slow 版压缩包中） |
| **操作系统** | Ubuntu 18.04+ / Debian 10+（其他 Linux 发行版可能需调整） |
| **Python** | 必须为 **CPython 3.7**（PyPy 不支持） |

> 📌 如需 `fast-sequential` 模型，请等待后续更新或手动调整模型路径。

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
3. 收到下载链接后，下载 **slow 版本**的 `signalp-6*.tar.gz`
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

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_fixed.sh

# 赋予执行权限
chmod +x install_signalp6_fixed.sh

# 运行（全程约 5-15 分钟，取决于网络速度）
./install_signalp6_fixed.sh
```

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
| `-m` | 运行模式（**仅支持 slow-sequential**） | `-m slow-sequential` |
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

### 示例：分析真核生物蛋白质

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
| `Python implementation is PyPy` | 环境使用了 PyPy | 删除重建环境：`conda remove -n signalp6 --all -y && ./install_signalp6_fixed.sh` |

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
COPY install_signalp6_fixed.sh /opt/
COPY signalp-6*.tar.gz /opt/
RUN cd /opt && bash install_signalp6_fixed.sh
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
│  │ 运行脚本     │  ./install_signalp6_fixed.sh        │
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

### v10（当前版本）

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

</div>
