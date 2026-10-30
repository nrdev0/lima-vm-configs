# Lima development VM

Use [Lima](https://lima-vm.io/) to run an Ubuntu development virtual machine (VM).
Use Ansible to install and configure its tools.

In this guide, **host** means your Mac. **VM** means the Ubuntu system.
Run host commands from this repository. Run VM commands as the regular user, without `sudo`.
Ansible uses `sudo` when necessary.

The VM has Ubuntu 26.04, 4 CPUs, 6 GiB of memory, and a 100 GiB disk.
The configuration tries a dated image with a pinned checksum first. If Ubuntu
has removed that image, it falls back to the latest Ubuntu 26.04 image, which
can change over time and does not use the dated image's checksum.
It includes these tools:

- Python 3.15 and uv.
- Git, GitHub CLI, curl, jq, ripgrep, and build tools.
- zsh and tmux.
- Codex CLI and Claude Code.

Projects stay inside the VM under `~/src`. The VM does not share host folders.
Containerd is disabled.

## Set up the VM

1. **On the host**, install Lima:

   ```bash
   brew install lima
   ```

   If Lima is installed, use `brew upgrade lima` instead.
   Use `limactl --version` to check the version. You need version 2.2.1 or later.

2. Create the VM. Select the command for your Mac.

   **Apple Silicon:**

   ```bash
   limactl start --name=dev-python ./dev-python-aarch64.yaml
   ```

   **Intel Mac with macOS 15.5 or later:**

   ```bash
   limactl start --name=dev-python ./dev-python-x86_64.yaml
   ```

3. Install the tools:

   ```bash
   bash scripts/provision dev-python
   ```

   This script installs Ansible inside the VM. It updates Ubuntu packages during the first setup.
   If necessary, it restarts the VM once and continues.

4. Open a VM shell:

   ```bash
   limactl shell dev-python
   ```

5. **In the VM**, check the setup:

   ```bash
   dev-doctor
   ```

   This command checks tools, storage, restart requirements, and security updates. It does not repair problems.
   Ubuntu's system Python and uv's development Python can have different versions. This is normal.

## Configure accounts

**In the VM**, run this optional command to configure your Git identity and GitHub access:

```bash
setup-git
```

For Codex, run `codex` from a project folder. Follow its sign-in instructions.
For Claude Code, run `claude` from a project folder. Follow its sign-in instructions.

Each service needs separate authentication. Ansible does not copy host credentials or sign you in.
`dev-doctor` checks the AI tool versions, but it does not check their authentication.

## Use the VM

**On the host**, use these commands:

| Task | Command |
| --- | --- |
| Show VM status | `limactl list` |
| Start the VM | `limactl start dev-python` |
| Open a VM shell | `limactl shell dev-python` |
| Stop the VM | `limactl stop dev-python` |

Starting the VM does not run Ansible. Installed tools and projects stay on the VM disk.
For an SSH editor connection, use `~/.lima/dev-python/ssh.config` on the host.

If you use Ghostty, run provisioning from Ghostty on the host.
The script copies its terminal definition into the VM when available on the host.
Outside tmux, keep the host's `TERM` value. Inside tmux, the configuration uses `tmux-256color`.
Do not set `TERM` in your shell configuration.

If you see an unknown terminal error, run this command on the host:

```bash
TERM=xterm-256color bash scripts/provision dev-python
```

Then open a new VM shell. For an existing tmux server, run `tmux source-file ~/.tmux.conf` inside the VM.
Open a new tmux window to use the updated terminal type.

**In the VM**, create a Python project:

```bash
cd ~/src
uv init --python 3.15 my-project
cd my-project
uv add --dev ruff pytest
uv run python --version
uv run ruff check .
```

Use `uv run` to run commands in the project's Python environment.
Commit `pyproject.toml`, `.python-version`, and `uv.lock`. Do not commit `.venv`.
After you clone an existing project, run `uv sync --locked` in its folder.

## Update the VM

Ubuntu installs security updates each day while the VM runs. These updates do not cause an automatic restart.
Use the commands below to request other updates.

Before maintenance, back up your projects. Close active AI sessions.

**On the host**, update Ubuntu packages and both AI tools:

```bash
bash scripts/provision dev-python \
  -e force_os_upgrade=true \
  -e force_ai_tools_update=true
```

The flags control separate updates:

| Flag | Effect |
| --- | --- |
| `force_os_upgrade=true` | Update installed Ubuntu packages through APT, including curl, Git, and tmux. |
| `force_ai_tools_update=true` | Run the native Codex and Claude Code installers again. |

Use either flag alone, or use both. This command does not change the Ubuntu release.
If a restart is necessary, the script restarts the VM once and continues. A restart disconnects active sessions.

To apply configuration changes without these update requests, run:

```bash
bash scripts/provision dev-python
```

After the first setup, this command installs missing packages and applies configuration changes.
It also installs missing or failed AI tools. It does not update working AI tools through their installers.
The AI tools keep their own default update behavior.

**In the VM**, use these commands for Python and project updates:

| Task | Command |
| --- | --- |
| Update Python 3.15 to a newer patch version | `uv python upgrade 3.15` |
| Update project dependencies | `uv lock --upgrade` |
| Install the locked dependencies | `uv sync --locked` |
| Run project tests, if present | `uv run pytest` |
| Check the VM after updates | `dev-doctor` |

Run project commands in the project folder. Review and commit lockfile changes after successful tests.

## Change the configuration

| File | Settings |
| --- | --- |
| `dev-python-*.yaml` | VM image, CPU, memory, disk, and container runtime. |
| `ansible/group_vars/all.yml` | Ubuntu packages, uv version, and Python version. |
| `dotfiles/` | Shell and tmux configuration. |

Change `uv_version` to update uv. Change `python_version` to install another Python version.
Then run `bash scripts/provision dev-python` on the host.
Existing Python installations and project version selections stay unchanged.

Edit dotfiles in this repository. Ansible replaces the VM copies and backs up changed files.

To preview Ansible changes, run this command on the host:

```bash
bash scripts/provision dev-python --check --diff
```

Use this preview after the first successful setup. It does not restart the VM.
On a new VM, it can install Ansible and cannot fully preview tool installation.

## Back up and restore projects

Backups are manual. Make a backup before maintenance or VM deletion.
Keep the VM running. Stop processes that write to project files.

**On the host**, create a backup:

```bash
bash scripts/backup dev-python
```

The script prints the backup path under `~/Backups/lima`.
Backups include `~/src`, Git history, and files you have not committed.
They exclude virtual environments, common caches, and VM account settings.
Files outside `~/src` are not included, even through symbolic links.

Backups can contain project secrets. They are not encrypted. Keep them private.
Back up active databases separately. Delete old backups manually when no longer needed.

To restore a backup, replace the example path with the printed backup path:

```bash
bash scripts/restore dev-python "$HOME/Backups/lima/projects-TIMESTAMP.SUFFIX"
```

The script checks the backup checksum. It restores files into a new `~/src-restored.*` folder in the VM.
It does not replace `~/src`.

Check the restored files before you move them into `~/src`.
Run `uv sync --locked` and your project tests in each restored project.
Verify the backup before you delete the original VM.
