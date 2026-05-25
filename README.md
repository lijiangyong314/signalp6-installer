# SignalP 6.0 Automated Installer

**Fully automated installation script for SignalP 6.0 (slow-sequential model)**  
Compatible with Ubuntu/Linux + Conda | Solves `libtiff.so.5`, PyTorch dependencies, setup hang, and more.

> ⚠️ **Important Limitation**  
> This script **only supports the `slow-sequential` pretrained model** (the `sequential_models_signalp6` directory from the official package).  
> **`fast-sequential` is NOT supported** – do not use `--mode fast-sequential`, as the required model files are missing.  
> If you need the fast model, please wait for future updates or manually adjust the paths.

## Prerequisites

- **OS**: Ubuntu 18.04+ / Debian 10+ (other Linux distros may need adjustments)
- **Conda**: [Miniconda](https://docs.conda.io/en/latest/miniconda.html) or Anaconda installed
- **Network**: Access to PyPI, conda-forge, and PyTorch download sources (Chinese users may want to configure pip mirrors)
- **SignalP archive**: Download `signalp-6*.tar.gz` from [DTU Health Tech](https://services.healthtech.dtu.dk/cgi-bin/sw_request?software=signalp&version=6.0) (**choose slow version**) and place it in `~/Desktop`, `~/Downloads`, or the script's directory.

> 📌 **Academic License Reminder**: SignalP 6.0 is for non-commercial academic use only. Please comply with DTU's license.

---

## Quick Start

### Step 1: Prepare the archive
Put the downloaded `signalp-6*.tar.gz` in `~/Desktop` or `~/Downloads`.

### Step 2: Download and run the script
```bash
curl -O https://raw.githubusercontent.com/lijiangyong314/signalp6-installer/main/install_signalp6_fixed.sh
chmod +x install_signalp6_fixed.sh
./install_signalp6_fixed.sh
