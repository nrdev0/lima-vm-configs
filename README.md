# lima-vm-configurations

Ubuntu development guests managed with [Lima](https://lima-vm.io/) and Ansible.

Lima owns VM resources, images, networking, mounts, and optional container
runtimes. The guest bootstrap installs Ansible; the playbook manages development
packages and user-level tools. Reapply it whenever your tool configuration changes.

Install Lima 2.0 or newer on macOS, then create a VM:

```bash
# Apple Silicon
limactl start --name=dev-python ./dev-python-aarch64.yaml
# Intel Mac alternative (macOS 15.5 or newer):
# limactl start --name=dev-python ./dev-python-x86_64.yaml
bash scripts/provision dev-python
limactl shell dev-python
```

Both `dev-python` configurations target native macOS virtualization with VZ.
Use `aarch64` on Apple Silicon and `x86_64` on an Intel Mac. The Ubuntu 26.04
image requires macOS 15.5 or newer on Intel with VZ; for Linux hosts or older
Intel Macs, use `vmType: qemu` instead. Both allocate 4 CPUs, 6 GiB RAM, and a
100 GiB virtual disk. This is the starting profile for an M3 Air with 16 GB RAM.

Both use Lima's default guest user and no host directory mounts. Keep projects
under `~/src` inside the guest and connect your editor using Lima's generated
SSH configuration (`~/.lima/dev-python/ssh.config` with the default Lima home).
Push or back up guest-local work before deleting or recreating the VM.

Containerd is disabled for this Python baseline. Set `containerd.user: true`
to enable Lima's rootless containerd and nerdctl. Workflows requiring the Docker
API, such as many Testcontainers setups, need a compatible runtime.

Ubuntu images are pinned to the same dated 26.04 LTS release for both
architectures, without a moving fallback. The URLs and checksums come from
[Lima's Ubuntu 26.04 template](https://github.com/lima-vm/lima/blob/9ad9d38eecfe9a79df13dc3e6a960a76f5c692d2/templates/_images/ubuntu-26.04.yaml).
Ubuntu may retire dated images; refresh the URL and checksum together when
needed. The networking workaround in `param` follows that upstream template.

On initial provisioning, Ansible refreshes package indexes and upgrades installed
OS packages before configuring development tools. It records success in
`/var/lib/lima-dev-setup/initial-upgrade.done`; subsequent runs skip that upgrade.
Existing guests without this marker also upgrade on their next provisioning run.
Lima's `upgradePackages: false` keeps upgrades from running on every boot.

If Ubuntu requires a reboot, provisioning stops before installing tools. Restart
the guest and rerun provisioning; the completed upgrade will be skipped:

```bash
limactl stop dev-python
limactl start dev-python
bash scripts/provision dev-python
```

For later maintenance, explicitly request another upgrade:

```bash
bash scripts/provision dev-python -e force_os_upgrade=true
```

If that run requires a reboot, restart and rerun without `force_os_upgrade=true`.

Review CPU, memory, and disk settings before creation. The original
`dev-default` configurations remain available. VM settings are separate from
the repeatable Ansible tool setup; changing the VM type requires recreation.

`scripts/provision` requires a running VM. It copies the playbook, repository
dotfiles, and guest bootstrap into a temporary guest directory, applies them,
and removes that copy.
No host Ansible installation or repository mount is required. Run it as the
normal Lima user with passwordless sudo enabled, as in these VM definitions.

Edit `ansible/group_vars/all.yml` to choose packages, the pinned uv version, and
Python version. Python 3.15 is a stable release, not an LTS edition: CPython
releases receive roughly five years of support. Use 3.14 instead if a project's
dependencies do not yet support 3.15. For example:

```bash
bash scripts/provision dev-python -e python_version=3.14
bash scripts/provision dev-python --syntax-check
```

Ansible installs uv and Python for the regular guest user. It keeps Ubuntu's
system Python for Ansible and OS tools. uv installs versioned executables such
as `python3.15`; projects choose their own interpreter and isolated environment.
Ansible also installs tmux and zsh, and makes zsh the guest user's login shell.
Reconnect your SSH editor or open a new session after provisioning. Lima keeps
Bash configured for bootstrap; the managed `.bash_profile` hands interactive
`limactl shell` sessions over to zsh. Noninteractive Bash scripts keep using Bash.

Dotfiles live in this repository under `dotfiles/`. Ansible copies `.zshenv`,
`.zshrc`, `.bash_profile`, and `.tmux.conf` into the guest home directory and
backs up existing files when replacing them. Edit the repository copies and
reprovision to apply changes; edits made only in the guest will be overwritten.
The zsh setup adds `~/.local/bin` to PATH, enables completion and persistent
history, and uses a basic prompt. New tmux windows use zsh.

For a new project inside the guest:

```bash
uv init --python 3.15 my-project
cd my-project
uv add requests
uv run python --version
```

Commit `pyproject.toml`, `.python-version`, and `uv.lock`. Use `uv sync --locked`
to reproduce the locked dependencies in CI or another checkout. Virtual
environments (`.venv`) stay local and should not be committed.

After the initial OS upgrade, routine provisioning installs missing packages.
It pins uv and disables uv self-updates; change `uv_version` and reprovision
to update it.
A Python minor version installs the latest patch known to that uv release when
missing. Existing Python installations are kept; use `uv python upgrade 3.15`
for deliberate patch upgrades, or set `python_version` to an exact patch for
repeatable interpreter selection. Changing Python versions leaves older
installations and project version choices in place.

For a repository already available inside the guest, use `bash scripts/setup`
directly. Ansible options are forwarded by both scripts. `--check --diff` is most
useful after the first successful setup; it still bootstraps Ansible if missing,
and a fresh guest cannot fully preview uv and Python installation.
