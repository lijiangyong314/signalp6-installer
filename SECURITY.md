# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| v10+    | :white_check_mark: |
| < v10   | :x:                |

## Reporting a Vulnerability

If you find a security vulnerability in this script, please:

1. **Do NOT open a public issue** — this would expose the vulnerability to all users.
2. Use GitHub's private vulnerability reporting:
   https://github.com/lijiangyong314/signalp6-installer/security/advisories/new

Include the following information:
- Type of issue
- Full paths of source file(s) related to the issue
- Location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

## What This Script Does (and Doesn't Do)

### What it DOES ✅
- Create an isolated Conda environment named `signalp6`
- Install Python packages via `pip` and `conda` from public repositories
- Copy model files from the official SignalP 6.0 distribution package
- Run diagnostic commands to verify the installation result
- Generate an environment check script for troubleshooting

### What it does NOT do ❌
- ❌ Collect or transmit any personal data or telemetry
- ❌ Download anything except explicitly listed packages from official sources:
  - PyPI / PyPI mirrors (NumPy, matplotlib, tqdm, Pillow)
  - conda-forge / Anaconda repos (Pillow)
  - download.pytorch.org (PyTorch CPU-only)
- ❌ Modify system files outside the Conda environment prefix
- ❌ Access files outside the working directory and Conda prefix
- ❌ Make network requests to unknown/untrusted servers
- ❌ Require root/sudo privileges (except optional `apt-get install libtiff5` as fallback)

## Full Network Transparency

All network requests made by this script go to **known, trusted servers**:

| Package | Source URL |
|---------|-----------|
| SignalP tarball | Downloaded by user beforehand (not by this script) |
| NumPy | pypi.org / pypi.tuna.tsinghua.edu.cn |
| Matplotlib | pypi.org / pypi.tuna.tsinghua.edu.cn |
| Pillow | repo.anaconda.com / conda-forge (conda-forge.org) |
| PyTorch | download.pytorch.org (official PyTorch server) |
| tqdm | pypi.org / pypi.tuna.tsinghua.edu.cn |

## Known Limitations

- The script runs with the permissions of the user who executes it. Always review scripts before running them.
- Package downloads depend on the security of PyPI, conda-forge, and PyTorch infrastructure.
- We recommend reviewing the source code before execution: it is a single ~500-line Bash script that is fully human-readable.

## License

This project is licensed under MIT. See [LICENSE](LICENSE) for details.

**SignalP 6.0 itself** follows DTU Health Tech's academic license terms.
