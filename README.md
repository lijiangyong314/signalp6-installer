🧬 SignalP 6.0 Automated Installer | SignalP 6.0 全自动安装脚本

<div align="center">

One-command deployment for SignalP 6.0 (fast + slow-sequential) on Ubuntu/Linux + Conda
一键部署 SignalP 6.0（fast + slow-sequential 模型）

https://img.shields.io/badge/Ubuntu-20.04%2B-orange?logo=ubuntu](https://ubuntu.com/)
https://img.shields.io/badge/Conda-Miniconda%7CAnaconda-green?logo=conda-forge](https://docs.conda.io/en/latest/miniconda.html)
https://img.shields.io/badge/Python-3.7-blue?logo=python&logoColor=white](https://www.python.org/)
https://img.shields.io/badge/License-MIT-yellow.svg](https://opensource.org/licenses/MIT)

#english--signalp-60-automated-installer | #信号肽-60-全自动安装脚本

</div>

✨ 为什么需要这个脚本？

SignalP 6.0 是 DTU Health Tech 开发的信号肽与跨膜区域预测工具，基于深度学习，是目前该领域最先进的工具之一。但官方只提供了手动安装步骤，在 Ubuntu/Linux + Conda 环境下存在多个已知的兼容性问题，手动排查非常耗时。

本脚本经过 15 轮迭代验证（v1 → v15），将繁琐的 8 步手动安装简化为一条命令，并自动修复了所有已知故障点。v15 是最终稳定版，解决了 v14 及之前版本的所有遗留问题，包括：
• ✅ Miniconda 自动安装报错（"Please run using bash/sh" 问题）

• ✅ conda run 触发 source 检测错误

• ✅ MKL 环境变量未绑定（MKL_INTERFACE_LAYER: 未绑定的变量）

• ✅ 依赖版本不兼容（numpy 1.26.x 不兼容 Python 3.7）

• ✅ setuptools 缺失导致编译失败

• ✅ conda tos accept 失败兼容性

💡 适用场景：生物信息学研究、蛋白质序列分析、信号肽预测、跨膜蛋白鉴定

⚠️ 重要限制

项目 说明

支持模型 ✅ fast（蒸馏模型，速度最快）和 slow-sequential（顺序模型，最高精度）

智能识别 ✅ 自动解析 signalp-6*.tar.gz 文件名，按模式分组并保留最高版本

操作系统 Ubuntu 18.04+ / Debian 10+（其他 Linux 发行版可能需调整）

Python 必须为 CPython 3.7（PyPy 不支持）

依赖版本 ✅ 严格锁定：numpy<1.22, matplotlib<3.7, tqdm<4.65, pillow<10

📌 脚本会自动扫描目录中的所有 SignalP 压缩包，交互式让你选择安装哪些模式。如果同模式有多个版本，自动保留最高版本。

📋 前置条件

条件 要求 说明

操作系统 Ubuntu 18.04+ / Debian 10+ 已测试 Ubuntu 22.04

Conda 可选，脚本可自动安装 Miniconda 无需预先安装

网络连接 可访问 PyPI / conda-forge / PyTorch 下载源 🇨🇳 中国用户建议配置镜像（见下方）

SignalP 安装包 从 https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0 下载 signalp-6*.tar.gz（支持 fast 和 slow-sequential 版本）

🇨🇳 中国用户网络优化（推荐）

如果访问 PyPI / conda-forge 较慢，建议提前配置镜像：
# pip 使用清华镜像
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# conda 使用清华镜像
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/
conda config --set show_channel_urls yes


📦 获取 SignalP 安装包

1. 访问 https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0
2. 填写学术用途申请表（免费，仅限非商业学术用途）
3. 收到下载链接后，下载 signalp-6*.tar.gz（支持 fast 和 slow-sequential 版本，可同时下载多个）
4. 将压缩包放置于以下任一目录：
   • ~/Desktop 或 ~/桌面

   • ~/Downloads 或 ~/下载

   • 脚本所在目录

   • 任意位置（脚本也会自动全盘搜索）

📌 学术许可提醒：SignalP 6.0 仅限非商业学术研究用途，请遵守 DTU 的许可协议。

🚀 快速开始（3 步搞定）

Step 1：准备安装包

将下载的 signalp-6*.tar.gz 放入上述目录之一。

Step 2：下载并运行脚本

方式 A：仅下载脚本（中文双语版 / Bilingual）
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v15.sh
chmod +x install_signalp6_v15.sh
./install_signalp6_v15.sh


方式 A2：仅下载脚本（英文版 / English）
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v15_en.sh
chmod +x install_signalp6_v15_en.sh
./install_signalp6_v15_en.sh


方式 B：克隆完整仓库（含 README 文档 + 脚本，推荐）
git clone https://github.com/lijiangyong314/signalp6-installer.git
cd signalp6-installer
chmod +x install_signalp6_v15.sh
./install_signalp6_v15.sh


💡 v15 重大改进：脚本现在可以完全自动化安装 Miniconda，无需预先安装 Conda！如果系统没有 Conda，脚本会提示自动安装到 ~/miniconda3。

Step 3：验证安装

conda activate signalp6
signalp6 --help


成功的话会显示 SignalP 6.0 的帮助信息。看到 🎉 安装成功！ 的提示即表示一切就绪 ✅

🔍 脚本执行流程详解

脚本共分为 8 个步骤，每步都有详细的日志输出和错误处理：

[0/8] 初始化 Conda          ← 检测/自动安装 Conda + 激活 shell hook
[1/8] 创建 Python 3.7 环境   ← 创建 signalp6 conda 环境（CPython + nomkl）
[2/8] 定位 signalp-6*.tar.gz ← 自动搜索常用目录 + 全盘扫描 + 手动输入兜底
[3/8] 解压安装包            ← 动态搜索 setup.py（兼容非标准目录名）
[4/8] 编译安装              ← 确保 setuptools 存在 + timeout 300s
[5/8] 安装所有依赖           ← Pillow → matplotlib → NumPy → PyTorch → tqdm
[6/8] 部署模型权重          ← 自动查找模型文件并复制
[7/8] 环境诊断              ← 生成 check_signalp_env.sh 诊断脚本
[8/8] 最终验证             ← 使用绝对路径执行 signalp6 --help


各步骤关键要点

步骤 功能 关键技术细节（v15 改进）

0 初始化 Conda 新增：可自动安装 Miniconda，添加 .sh 后缀绕过 $0 检测

1 创建环境 新增：强制使用 nomkl 避免 MKL 冲突，自动检测并重建含 MKL 的环境

2 定位压缩包 多级搜索策略：常用目录 → 工作目录 → /home 全盘搜索（限时 30 秒）→ 手动输入

3 解压 用 find -name setup.py 动态定位源码目录，不硬编码路径

4 编译安装 新增：确保 setuptools 存在，timeout 300 防卡死

5a Pillow 修复 版本锁定：pillow<10 避免高版本兼容问题

5b matplotlib 版本锁定：matplotlib<3.7 确保 Python 3.7 兼容

5c NumPy 版本锁定：numpy<1.22 确保 Python 3.7 兼容

5d PyTorch 优先 pip 安装 1.8.1+cpu（CPU only）

5e tqdm 版本锁定：tqdm<4.65 避免 tqdm.auto 错误

5f import 验证 所有依赖就绪后才尝试 import signalp

6 模型权重 多路径搜索解压包内、桌面、Home 目录等位置

7 诊断 生成独立可复用的 check_signalp_env.sh 脚本

8 最终验证 改进：使用绝对路径 $CONDA_BASE/envs/signalp6/bin/signalp6 避免 conda run 问题

📖 使用方法

基本用法

# 激活环境
conda activate signalp6

# 运行预测（基本参数）
signalp6 -i input.fasta -o output_dir -m slow-sequential

# 查看完整帮助
signalp6 --help


常用参数

参数 说明 示例

-i 输入 FASTA 文件路径 -i proteins.fasta

-o 输出目录 -o results/

-m 运行模式（fast 或 slow-sequential） -m fast 或 -m slow-sequential

--organism 生物体类型（euk/gram+/gram-/meta） --organism euk

--format 输出格式（short/long/json/csv/tsv） --format json

--batchsize 批处理大小（默认 512） --batchsize 256

--cpu CPU 线程数 --cpu 4

输出文件说明

运行完成后，输出目录中会包含以下文件：

文件 说明

predictions.json JSON 格式的预测结果（含置信度分数）

summary.txt 摘要报告

output.gff3 GFF3 格式注释文件

output.fasta 处理后的序列文件

示例：分析真核生物蛋白质（slow-sequential 模式）

conda activate signalp6

signalp6 \
  -i my_proteins.fasta \
  -o signalp_results \
  -m slow-sequential \
  --organism euk \
  --format long \
  --cpu 4


示例：快速预测（fast 模式）

conda activate signalp6

signalp6 \
  -i my_proteins.fasta \
  -o signalp_results \
  -m fast \
  --format json


🛠️ 故障排查

一键诊断

安装后或遇到问题时，先运行诊断脚本：
conda activate signalp6
bash check_signalp_env.sh


这会输出完整的依赖状态报告。

常见问题速查表（v15 已修复的问题）

错误信息 原因 v15 解决方案

Please run using "bash"/"dash" Miniconda 安装脚本检测 $0 后缀 自动添加 .sh 后缀绕过检测

conda run 触发 source 检测 conda run 在非交互式 shell 中报错 使用绝对路径代替 conda run

MKL_INTERFACE_LAYER: 未绑定的变量 MKL 激活脚本使用未定义变量 创建环境时强制加入 nomkl，自动检测并重建

numpy 1.26.x 不兼容 Python 3.7 pip 默认安装最新版 严格版本锁定：numpy<1.22

ModuleNotFoundError: setuptools 环境缺少 setuptools 创建环境时包含，编译前二次检查

conda tos accept 失败 旧版 conda 不支持 使用绝对路径 + 错误抑制

手动修复流程

如果自动安装失败，可以按以下顺序手动修复：
# 1. 激活环境
conda activate signalp6

# 2. 解决 MKL 问题（如存在）
conda remove -n signalp6 --all -y
conda create -n signalp6 python=3.7 pip setuptools nomkl -c conda-forge -y
conda activate signalp6

# 3. 安装严格版本控制的依赖
pip install "numpy>=1.19,<1.22"
pip install "matplotlib>=3.3.2,<3.7"
pip install "tqdm<4.65"
pip install "pillow<10"
pip install torch==1.8.1+cpu torchvision==0.9.1+cpu -f https://download.pytorch.org/whl/torch_stable.html

# 4. 验证
python -c "import signalp; print('✅ SignalP 6.0 就绪')"
signalp6 --help


🔬 技术细节：v15 解决的核心问题

🐛 Bug #1：Miniconda 安装脚本的 source 检测

现象：

Please run using "bash"/"dash"/"sh"/"zsh", but not "." or "source".


根因：Miniconda 安装脚本内部检查 $0 是否以 .sh 结尾，脚本生成的临时文件名（如 /tmp/miniconda3_installer_12345）没有 .sh 后缀。

v15 修复：
local installer_with_sh="${installer}.sh"
mv "$installer" "$installer_with_sh"
bash "$installer_with_sh" -b -p "$HOME/miniconda3"


🐛 Bug #2：conda run 触发 source 检测错误

现象：conda run -n signalp6 python --version 同样触发上述错误。

v15 修复：彻底避免使用 conda run，改用绝对路径：
"$CONDA_BASE/envs/signalp6/bin/python" --version
"$CONDA_BASE/envs/signalp6/bin/signalp6" --help


🐛 Bug #3：MKL 环境变量未绑定

现象：

/home/xxx/miniconda3/envs/signalp6/etc/conda/activate.d/libblas_mkl_activate.sh: 行 1: MKL_INTERFACE_LAYER: 未绑定的变量


根因：conda 环境中安装了 MKL（Intel Math Kernel Library），其激活脚本使用了未定义的环境变量，而脚本开头 set -u 导致退出。

v15 修复：
1. 创建环境时强制加入 nomkl：
   conda create -n signalp6 python=3.7 pip setuptools nomkl -c conda-forge -y
   
2. 自动检测并重建含 MKL 的环境

🐛 Bug #4：依赖版本不兼容

现象：numpy 1.26.x 需要 Python ≥3.9，但在 Python 3.7 上安装导致失败。

v15 修复：严格版本锁定：
NUMPY_CONSTRAINT=">=1.19,<1.22"        # 原 <2.0
MATPLOTLIB_CONSTRAINT=">=3.3.2,<3.7"   # 原 <5.0
PILLOW_CONSTRAINT="<10"                # 原 <11
TQDM_CONSTRAINT="<4.65"                # 原 <4.66


🐛 Bug #5：setuptools 缺失

现象：ModuleNotFoundError: No module named 'setuptools'

v15 修复：双保险策略：
1. 创建环境时包含 setuptools
2. 编译前再次检查并安装

🐛 Bug #6：conda tos accept 失败

现象：旧版 conda 不支持 tos accept 命令。

v15 修复：使用绝对路径 + 错误抑制：
"$CONDA_BASE/bin/conda" tos accept --override-channels --channel ... 2>/dev/null || true


🗑️ 卸载方法

# 1. 删除 conda 环境（包含所有已安装的依赖）
conda remove -n signalp6 --all -y

# 2. （可选）删除脚本生成的临时文件
rm -rf ~/signalp_extracted*/      # 解压临时目录
rm -f ~/check_signalp_env.sh      # 诊断脚本
rm -f ~/.signalp6_install_state   # 断点续装状态文件

# 3. （可选）从 conda 环境列表确认已清理
conda env list | grep signalp    # 应该无输出


❓ FAQ（常见问题）

Q1：v15 相比 v14 有哪些重大改进？

• ✅ Miniconda 自动安装：无需预先安装 Conda，脚本可全自动安装

• ✅ 彻底解决 source 检测错误：Miniconda 安装和 conda run 不再报错

• ✅ MKL 冲突自动解决：创建环境时使用 nomkl，自动检测并重建

• ✅ 依赖版本严格锁定：确保所有依赖兼容 Python 3.7

• ✅ 绝对路径调用：避免 conda run 相关问题

• ✅ setuptools 双保险：确保编译前 setuptools 存在

Q2：为什么必须是 Python 3.7？

SignalP 6.0 官方要求 Python 3.7，因为其依赖的某些库（特别是早期版本的 torch 和相关绑定）对更高版本 Python 存在兼容性问题。脚本强制创建 Python 3.7 环境。

Q3：fast 和 slow-sequential 有什么区别？

• fast：使用蒸馏模型（distilled_model_signalp6.pt，~400MB），预测速度最快，精度略低，适合大规模筛选

• slow-sequential：使用 7 个模型的集成（sequential_models_signalp6/，~2GB），精度最高但速度较慢（逐条处理），适合精细分析

Q4：可以在没有 Conda 的系统上运行吗？

可以！ v15 的重大改进就是支持自动安装 Miniconda。如果系统没有 Conda，脚本会提示并自动安装到 ~/miniconda3，无需 root 权限。

Q5：安装大概需要多久？

取决于网络速度：
• 快速网络（直连 PyPI）：~5-8 分钟

• 普通网络（使用镜像）：~10-15 分钟

• 首次运行（需安装 Miniconda）：额外增加 ~3-5 分钟

Q6：可以在服务器上运行吗？

可以！本脚本专为无 GUI 的 Linux 服务器设计。v15 使用绝对路径调用，更适合在非交互式 shell 中运行。

📊 安装流程图（v15 优化版）


┌───────────────────────────────────────────────────────┐
│            SignalP 6.0 自动安装流程 v15                │
├───────────────────────────────────────────────────────┤
│                                                       │
│  ┌─────────┐                                         │
│  │ 准备工作  │  signalp-6*.tar.gz（无需预先安装 Conda） │
│  └────┬────┘                                         │
│       ▼                                               │
│  ┌─────────────┐                                     │
│  │ 运行脚本     │  ./install_signalp6_v15.sh        │
│  └────┬────────┘                                     │
│       ▼                                               │
│  ┌─────────────────────────────────────┐             │
│  │ Step 0: 自动检测/安装 Conda          │             │
│  │ • 检测现有 Conda                     │             │
│  │ • 如无，自动安装 Miniconda (+.sh 后缀绕过检测) │
│  └──────────────┬──────────────────────┘             │
│                 ▼                                      │
│  ┌─────────────────────────────────────┐             │
│  │ Step 1-4: 环境准备 & 编译安装         │             │
│  │ • 创建 signalp6 (Python 3.7 + nomkl) │             │
│  │ • 搜索 & 解压 tar.gz                 │             │
│  │ • 确保 setuptools 存在              │             │
│  │ • timeout 300 setup.py install       │             │
│  └──────────────┬──────────────────────┘             │
│                 ▼                                      │
│  ┌─────────────────────────────────────┐             │
│  │ Step 5: 依赖安装（严格版本控制）      │             │
│  │ • numpy<1.22, matplotlib<3.7        │             │
│  │ • tqdm<4.65, pillow<10              │             │
│  │ • PyTorch 1.8.1 CPU                 │             │
│  └──────────────┬──────────────────────┘             │
│                 ▼                                      │
│  ┌──────────────────┐                                │
│  │ Step 6-8: 最终步骤 │ 模型+诊断+验证（绝对路径调用） │
│  └────────────┬─────┘                                │
│               ▼                                        │
│     ┌─────────────┐                                   │
│     │ 🎉 安装成功！ │                                   │
│     └─────────────┘                                   │
│                                                       │
└───────────────────────────────────────────────────────┘


📝 更新日志

v15（当前版本 - 最终稳定版）

• ✅ 彻底解决 Miniconda 自动安装报错：给安装包添加 .sh 后缀，绕过 $0 检测

• ✅ 避免 conda run 触发 source 检测：全部改用绝对路径调用

• ✅ 解决 MKL 环境变量未绑定：创建环境时强制加入 nomkl，自动检测并重建含 MKL 的环境

• ✅ 严格依赖版本控制：

  • numpy<1.22（原 <2.0）

  • matplotlib<3.7（原 <5.0）

  • tqdm<4.65（原 <4.66）

  • pillow<10（原 <11）

• ✅ 确保 setuptools 存在：创建环境时包含，编译前二次检查

• ✅ conda tos accept 容错：使用绝对路径 + 错误抑制

• ✅ 环境变量欺骗：设置 PS1 和 BASH_ENV 防止 conda 的 source 检测

• ✅ 断点续装功能完整保留：支持从任意步骤恢复安装

v14

• 新增 fast 模式支持（蒸馏模型 distilled_model_signalp6.pt）

• 智能压缩包去重：自动从 signalp-{ver}.{mode}.tar.gz 文件名解析模式和版本

• 交互式模式选择：运行时显示可用模式菜单

• 按需解压：只解压用户选择的模式包

• 中英双语输出 / 英文版脚本

v13

• 多 tar.gz 包智能解析和版本去重

• 交互式模式选择菜单

• 修复 rm -rf 安全问题

• 修复 stdout/stderr 混合导致的 TARGET_MODES 重复

v10-v12

• 实机验证确认模型文件结构

• 新增 eval "$(conda shell.bash hook)" 解决 conda activate 问题

• 生成独立的 check_signalp_env.sh 诊断脚本

• 增加中国用户镜像配置指南

v1-v9

• 基础自动化框架

• libtiff.so.5 修复方案定型

• timeout 300 防止 setup.py 卡死

• 依赖安装顺序修正

📄 许可证

本项目脚本采用 LICENSE 开源。

SignalP 6.0 本身遵循 DTU Health Tech 的学术许可协议，仅限非商业研究用途。
请参考官方许可条款：https://services.healthtech.dtu.dk/service.php?SignalP-6.0

🙏 致谢

• https://services.healthtech.dtu.dk/service.php?SignalP-6.0 — DTU Health Tech

• https://docs.conda.io/ — 包管理与虚拟环境

• https://pytorch.org/ — 深度学习框架

🤝 贡献

欢迎提交 Issue 和 Pull Request！

• 发现新的兼容性问题？ → 请开 https://github.com/lijiangyong314/signalp6-installer/issues

• 有改进建议？ → 欢迎 PR

• 成功安装了？ → 欢迎 ⭐ Star 让更多人知道这个工具！

<div align="center">

⭐ 如果这个脚本帮到了你，请给一个 Star 支持！⭐

让更多生物信息学研究者不再被 SignalP 6.0 的安装问题困扰 🧬

⭐ If this script helped you, please give it a Star! ⭐

Save fellow bioinformaticians from the pain of installing SignalP 6.0 🧬

</div>

<a id="english--signalp-60-automated-installer"></a>
🧬 SignalP 6.0 Automated Installer

<div align="center">

One-command deployment for SignalP 6.0 (fast + slow-sequential model) on Ubuntu/Linux + Conda

https://img.shields.io/badge/Ubuntu-20.04%2B-orange?logo=ubuntu](https://ubuntu.com/)
https://img.shields.io/badge/Conda-Miniconda%7CAnaconda-green?logo=conda-forge](https://docs.conda.io/en/latest/miniconda.html)
https://img.shields.io/badge/Python-3.7-blue?logo=python&logoColor=white](https://www.python.org/)
https://img.shields.io/badge/License-MIT-yellow.svg](https://opensource.org/licenses/MIT)

</div>

✨ Why This Script?

SignalP 6.0 is the state-of-the-art signal peptide and transmembrane domain prediction tool from DTU Health Tech, powered by deep learning. This script has been iteratively tested and refined over 15 rounds (v1 → v15), reducing the tedious manual installation to a single command, with automatic fixes for all known issues.

v15 is the final stable release that solves all remaining problems from v14 and earlier:
• ✅ Miniconda auto-install error ("Please run using bash/sh")

• ✅ conda run triggers source detection error

• ✅ MKL unbound variable (MKL_INTERFACE_LAYER: unbound variable)

• ✅ Dependency version incompatibility (numpy 1.26.x requires Python ≥3.9)

• ✅ Missing setuptools causing build failure

• ✅ conda tos accept failure compatibility

💡 Use cases: Bioinformatics research, protein sequence analysis, signal peptide prediction, transmembrane protein identification

⚠️ Important Limitations

Item Details

Supported models ✅ fast (distilled, fastest) and slow-sequential (ensemble, highest accuracy)

Smart detection ✅ Auto-parse signalp-6*.tar.gz filenames, group by mode, keep highest version

OS Ubuntu 18.04+ / Debian 10+ (other distros may need adjustments)

Python Must be CPython 3.7 (PyPy not supported)

Dependency versions ✅ Strictly pinned: numpy<1.22, matplotlib<3.7, tqdm<4.65, pillow<10

📋 Prerequisites

Requirement Details

OS Ubuntu 18.04+ / Debian 10+ (tested on Ubuntu 22.04)

Conda Optional, script can auto-install Miniconda
Network Access to PyPI / conda-forge / PyTorch download servers

SignalP package Download signalp-6*.tar.gz (fast and/or slow-sequential versions) from https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0

Getting the SignalP Package

1. Visit https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0
2. Fill in the academic use application form (free, non-commercial academic use only)
3. Download fast and/or slow-sequential versions of signalp-6*.tar.gz after receiving the download link
4. Place the archive in any of these directories: ~/Desktop, ~/Downloads, script directory, or anywhere (the script will search automatically)

🚀 Quick Start (3 Steps)

Step 1: Prepare the Package

Place signalp-6*.tar.gz in one of the directories listed above.

Step 2: Download & Run

Option A: Script only (Bilingual)
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v15.sh
chmod +x install_signalp6_v15.sh
./install_signalp6_v15.sh


Option A2: Script only (English)
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_v15_en.sh
chmod +x install_signalp6_v15_en.sh
./install_signalp6_v15_en.sh


Option B: Full repo clone (recommended)
git clone https://github.com/lijiangyong314/signalp6-installer.git
cd signalp6-installer
chmod +x install_signalp6_v15.sh
./install_signalp6_v15.sh


💡 v15 Major Improvement: The script now supports fully automatic Miniconda installation! If Conda is not detected, the script will prompt to install it to ~/miniconda3 automatically.

Step 3: Verify

conda activate signalp6
signalp6 --help


If you see the SignalP 6.0 help message, installation is successful ✅

🔍 Installation Pipeline (8 Steps)


[0/8] Initialize Conda         ← Detect/auto-install Conda + activate shell hook
[1/8] Create Python 3.7 env    ← Create signalp6 conda env (CPython + nomkl)
[2/8] Locate signalp-6*.tar.gz ← Auto-search common dirs + full scan + manual fallback
[3/8] Extract                  ← Dynamic setup.py search (non-standard dir names OK)
[4/8] Build & Install          ← Ensure setuptools + timeout 300s
[5/8] Install Dependencies     ← Pillow → matplotlib → NumPy → PyTorch → tqdm
[6/8] Deploy Model Weights     ← Auto-find and copy model files
[7/8] Environment Diagnostics  ← Generate check_signalp_env.sh
[8/8] Final Verification       ← Use absolute path for signalp6 --help


Key Technical Decisions (v15 Improvements)

Step What Key Detail (v15)

0 Init Conda NEW: Auto-install Miniconda, add .sh suffix to bypass $0 detection

1 Create env NEW: Force nomkl to avoid MKL conflict, auto-detect and rebuild

2 Find tarball Multi-level search: common dirs → workdir → /home scan (30s limit) → manual input

3 Extract find -name setup.py dynamic locate, no hardcoded paths

4 Build NEW: Ensure setuptools exists, timeout 300 anti-hang

5a Pillow fix Version pin: pillow<10 avoid high-version issues

5b matplotlib Version pin: matplotlib<3.7 for Python 3.7 compat

5c NumPy Version pin: numpy<1.22 for Python 3.7 compat

5d PyTorch pip install 1.8.1+cpu (CPU only)

5e tqdm Version pin: tqdm<4.65 avoid tqdm.auto error

5f Import verify Only attempt import signalp after ALL dependencies ready

6 Model weights Multi-path search: extracted pkg, Desktop, Home, etc.

7 Diagnostics Generate standalone reusable diagnostic script

8 Verify IMPROVED: Use absolute path $CONDA_BASE/envs/signalp6/bin/signalp6

📖 Usage

Basic Usage

conda activate signalp6
signalp6 -i input.fasta -o output_dir -m slow-sequential
signalp6 -i input.fasta -o output_dir -m fast
signalp6 --help


Common Parameters

Parameter Description Example

-i Input FASTA file -i proteins.fasta

-o Output directory -o results/

-m Run mode (fast or slow-sequential) -m fast or -m slow-sequential

--organism Organism type (euk/gram+/gram-/meta) --organism euk

--format Output format (short/long/json/csv/tsv) --format json

--batchsize Batch size (default 512) --batchsize 256

--cpu Number of CPU threads --cpu 4

Example: Eukaryotic Protein Analysis (slow-sequential)

conda activate signalp6

signalp6 \
  -i my_proteins.fasta \
  -o signalp_results \
  -m slow-sequential \
  --organism euk \
  --format long \
  --cpu 4


Example: Fast Prediction (fast)

conda activate signalp6

signalp6 \
  -i my_proteins.fasta \
  -o signalp_results \
  -m fast \
  --format json


🛠️ Troubleshooting

Quick Diagnosis

conda activate signalp6
bash check_signalp_env.sh


Common Issues (Fixed in v15)

Error Cause v15 Solution

Please run using "bash"/"dash" Miniconda installer checks $0 suffix Auto-add .sh suffix to bypass

conda run triggers source detection conda run in non-interactive shell Use absolute paths instead of conda run

MKL_INTERFACE_LAYER: unbound variable MKL activation script uses undefined vars Force nomkl in env creation, auto-detect and rebuild

numpy 1.26.x incompatible with Python 3.7 pip installs latest by default Strict version pin: numpy<1.22

ModuleNotFoundError: setuptools Environment missing setuptools Include in env creation, double-check before build

conda tos accept fails Old conda versions don't support Use absolute path + error suppression

Manual Fix Procedure

# 1. Activate environment
conda activate signalp6

# 2. Fix MKL issue (if present)
conda remove -n signalp6 --all -y
conda create -n signalp6 python=3.7 pip setuptools nomkl -c conda-forge -y
conda activate signalp6

# 3. Install strictly version-controlled dependencies
pip install "numpy>=1.19,<1.22"
pip install "matplotlib>=3.3.2,<3.7"
pip install "tqdm<4.65"
pip install "pillow<10"
pip install torch==1.8.1+cpu torchvision==0.9.1+cpu -f https://download.pytorch.org/whl/torch_stable.html

# 4. Verify
python -c "import signalp; print('✅ SignalP 6.0 ready')"
signalp6 --help


🔬 Technical Details: Core Problems Solved in v15

🐛 Bug #1: Miniconda Installer Source Detection

Symptom: Please run using "bash"/"dash"/"sh"/"zsh", but not "." or "source".

Root cause: Miniconda installer checks if $0 ends with .sh.

v15 Fix: Add .sh suffix to temporary installer file.

🐛 Bug #2: conda run Triggers Source Detection

Symptom: conda run -n signalp6 python --version triggers same error.

v15 Fix: Avoid conda run entirely, use absolute paths instead.

🐛 Bug #3: MKL Unbound Variable

Symptom: MKL_INTERFACE_LAYER: unbound variable in activation script.

v15 Fix: Force nomkl in environment creation, auto-detect and rebuild MKL-containing environments.

🐛 Bug #4: Dependency Version Incompatibility

Symptom: numpy 1.26.x requires Python ≥3.9, fails on Python 3.7.

v15 Fix: Strict version pins for all critical dependencies.

🐛 Bug #5: Missing setuptools

Symptom: ModuleNotFoundError: No module named 'setuptools'

v15 Fix: Double insurance: include in env creation, check and install before build.

🐛 Bug #6: conda tos accept Failure

Symptom: Old conda versions don't support tos accept command.

v15 Fix: Use absolute path + error suppression.

🗑️ Uninstallation

# Remove conda environment (includes all dependencies)
conda remove -n signalp6 --all -y

# Optional: clean up generated files
rm -rf ~/signalp_extracted*/
rm -f ~/check_signalp_env.sh
rm -f ~/.signalp6_install_state

# Confirm cleanup
conda env list | grep signalp   # should return nothing


❓ FAQ

Q: What are the major improvements in v15 over v14?
• ✅ Miniconda auto-install: No need to pre-install Conda

• ✅ Eliminated source detection errors: Miniconda install and conda run no longer fail

• ✅ Auto MKL conflict resolution: Force nomkl in env creation, auto-detect and rebuild

• ✅ Strict dependency version pins: All deps guaranteed compatible with Python 3.7

• ✅ Absolute path calls: Avoid conda run issues

• ✅ setuptools double insurance: Ensure setuptools exists before compilation

Q: Why Python 3.7?
SignalP 6.0 officially requires Python 3.7 due to dependency compatibility (especially early PyTorch versions). The script creates a dedicated Python 3.7 environment.

Q: What's the difference between fast and slow-sequential?
• fast: Single distilled model (distilled_model_signalp6.pt, ~400MB). Fastest, slightly lower accuracy. Best for large-scale screening.

• slow-sequential: Ensemble of 7 sequential models (~2GB). Highest accuracy but slower (processes one sequence at a time). Best for detailed analysis.

Q: Can I run on a system without Conda?
Yes! v15's major improvement is automatic Miniconda installation. If no Conda is detected, the script will prompt to install to ~/miniconda3 automatically.

Q: How long does installation take?
• Fast network: ~5-8 minutes

• Normal network (mirrors): ~10-15 minutes

• First run (needs Miniconda): Extra ~3-5 minutes

Q: Can I run on a headless server?
Yes! Designed for SSH-only Linux servers. v15's absolute path calls work better in non-interactive shells.

📝 Changelog

v15 (Current - Final Stable)

• ✅ Fixed Miniconda auto-install error: Add .sh suffix to bypass $0 detection

• ✅ Avoid conda run source detection: Use absolute paths instead

• ✅ Solved MKL unbound variable: Force nomkl in env creation, auto-detect and rebuild

• ✅ Strict dependency version control:

  • numpy<1.22 (was <2.0)

  • matplotlib<3.7 (was <5.0)

  • tqdm<4.65 (was <4.66)

  • pillow<10 (was <11)

• ✅ Ensure setuptools exists: Include in env creation, double-check before build

• ✅ conda tos accept fault tolerance: Use absolute path + error suppression

• ✅ Environment variable spoofing: Set PS1 and BASH_ENV to prevent conda source detection

• ✅ Checkpoint resume fully preserved: Can resume from any interrupted step

v14

• Added fast mode support (distilled model distilled_model_signalp6.pt)

• Smart package dedup: auto-parse signalp-{ver}.{mode}.tar.gz filenames

• Interactive mode selection: runtime menu showing available modes

• On-demand extraction: only extract selected mode packages

• Bilingual output / English-only version

v13

• Multi-tarball smart parsing and version dedup

• Interactive mode selection menu

• Fixed rm -rf safety issue

• Fixed stdout/stderr mixing causing TARGET_MODES duplication

v10-v12

• Real-machine validation of model file structure

• Added eval "$(conda shell.bash hook)" for reliable conda activation

• Standalone check_signalp_env.sh diagnostic script

• Mirror configuration guide for Chinese users

v1-v9

• Basic automation framework

• libtiff.so.5 fix finalized

• timeout 300 for setup.py anti-hang

• Dependency order correction

📄 License

This project is licensed under the LICENSE.

SignalP 6.0 itself follows DTU Health Tech's academic license (non-commercial research only).
See official terms: https://services.healthtech.dtu.dk/service.php?SignalP-6.0

🙏 Acknowledgments

• https://services.healthtech.dtu.dk/service.php?SignalP-6.0 — DTU Health Tech

• https://docs.conda.io/ — Package management & virtual environments

• https://pytorch.org/ — Deep learning framework

🤝 Contributing

Issues and Pull Requests are welcome!

• Found a new compatibility issue? → Open an https://github.com/lijiangyong314/signalp6-installer/issues

• Improvement ideas? → PRs welcome

• Successfully installed? → ⭐ Star to help others discover this tool!

<div align="center">

⭐ If this script helped you, please give it a Star! ⭐

Help more bioinformaticians escape the pain of installing SignalP 6.0 🧬

</div>

#-signalp-60-automated-installer--signalp-60-全自动安装脚本