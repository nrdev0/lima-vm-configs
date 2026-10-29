# lima-vm-configurations

Ubuntu development guests managed with [Lima](https://lima-vm.io/) and Ansible.

Lima owns VM resources, images, networking, mounts, and optional container
runtimes. The guest bootstrap installs Ansible; the playbook manages development
packages and user-level tools. Reapply it whenever your tool configuration changes.

Install [Lima 2.2.1](https://github.com/lima-vm/lima/releases/tag/v2.2.1) or newer
on macOS, then create a VM. Version 2.2.1 is the latest stable release as of
2026-10-28 and supports the Ubuntu 26.04 networking workaround used here.

```bash
brew install lima
# If Lima is already installed:
# brew upgrade lima
limactl --version
```

Create and provision the guest:

```bash
# Apple Silicon
limactl start --name=dev-python ./dev-python-aarch64.yaml
# Intel Mac alternative (macOS 15.5 or newer):
# limactl start --name=dev-python ./dev-python-x86_64.yaml
bash scripts/provision dev-python
limactl shell dev-python
# Inside the guest, optionally configure Git identity and GitHub authentication:
setup-git
dev-doctor
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

To back up projects, run this from the repository on your Mac while the VM is
running. Pause builds and other processes writing to the projects during backup:

```bash
bash scripts/backup dev-python
# Or choose a destination on your Mac or an external disk:
bash scripts/backup dev-python "$HOME/Backups/dev-python"
```

The default destination is `~/Backups/lima` on the host. Each invocation creates
a new, private snapshot directory and prints its path. It contains a compressed
archive, a SHA-256 checksum, and the source VM name. The archive includes the
contents of the guest's `~/src`, including `.git`, unpushed commits, uncommitted
changes, and untracked files. It excludes `.venv`, `__pycache__`, `.pytest_cache`,
`.ruff_cache`, `.mypy_cache`, `.tox`, and `.nox`. Symlinks are preserved; their
targets outside `~/src` are not included. Failed backups are removed.

Backups are manual: take one regularly and before maintenance or VM deletion.
Snapshots are not automatically pruned. They may contain `.env` files and other
project secrets and are not encrypted by these scripts; keep the destination
private and include it in your host backup plan. Running databases need their own
consistent dumps. Guest-global settings and GitHub credentials are not included.

Verify recovery while the original VM still exists, or restore to a newly
provisioned guest. Replace the snapshot path below with the one backup printed:

```bash
bash scripts/restore dev-python "$HOME/Backups/lima/projects-TIMESTAMP.SUFFIX"
```

Restore verifies the checksum, then extracts into a new `~/src-restored.*`
directory inside the guest. It never merges into or overwrites `~/src`. Inspect
the restored projects and their Git status, confirm untracked files are present,
and run `uv sync --locked` in a restored project to recreate its environment.
Run that project's normal checks before relying on the backup. Move recovered
projects into `~/src` only after reviewing them.

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
Bootstrap retries failed APT commands up to three times, waits up to five minutes
for package-install locks per attempt, and retries download failures. Ansible's
package tasks also use bounded retries and a five-minute package-lock timeout.

If Ubuntu requires a reboot, the host's `scripts/provision` automatically stops
and starts the VM, waits for Lima to report it ready, and resumes setup before
installing tools. The completed OS upgrade is skipped on the resumed run.
This also handles guests left at the reboot-required error by an earlier run:
just rerun `bash scripts/provision dev-python` from the host.
Automatic recovery allows one restart per invocation; other provisioning errors
stop immediately. A restart disconnects any active guest sessions.

For later maintenance, explicitly request another upgrade:

```bash
bash scripts/provision dev-python -e force_os_upgrade=true
```

If that run requires a reboot, provisioning resumes with `force_os_upgrade=false`
so the explicit upgrade is not repeated.

After provisioning, Ubuntu's daily APT timers refresh package indexes and apply
security updates through `unattended-upgrades`. The managed policy allows the
base release and security pocket, leaving general updates to explicit maintenance.
It disables automatic reboots; a pending reboot is reported by `dev-doctor` and
handled when you next run provisioning. Schedule deliberate maintenance between
work sessions, for example monthly. Timers run while the VM is running and may
catch up after it starts. The policy is in `ansible/tasks/security-updates.yml`.

Review CPU, memory, and disk settings before creation. VM settings are separate
from the repeatable Ansible tool setup; changing the VM type requires recreation.

`scripts/provision` requires a running VM. It copies the playbook, repository
dotfiles, and guest bootstrap into a temporary guest directory, applies them,
and removes that copy.
It also installs `setup-git` and `dev-doctor` in `~/.local/bin` so both commands
remain available after the temporary copy is removed, and creates `~/src`.
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

Git and GitHub CLI (`gh`) are installed by Ansible. Run `setup-git` inside an
interactive guest shell, without sudo, to configure them. The command offers:

- Commit display name and email, with existing guest Git settings as defaults.
  Use your verified GitHub email or the `noreply` address from your GitHub email
  settings. You can skip identity configuration to preserve it unchanged.
- Browser sign-in for HTTPS, reuse of an existing GitHub CLI login, or skipping
  authentication. Complete browser sign-in on your Mac using the URL and device
  code shown in the terminal. An existing valid login is the default when found.

Identity configuration sets `user.useConfigOnly=true` to prevent Git from
guessing an identity, and defaults new repositories to `main` if no global
default branch is already configured. Repository-specific settings still take
precedence. Other Git preferences are preserved.

After sign-in, `setup-git` checks authentication and makes GitHub CLI the HTTPS
credential helper for GitHub. Use `gh repo clone OWNER/REPO` or an HTTPS URL such
as `git clone https://github.com/OWNER/REPO.git`. Existing SSH remotes are not
converted. Authentication persists across VM restarts; recreating the guest
requires signing in again. On a guest without a system credential store, GitHub
CLI may store its token in its guest configuration file. Tokens are not passed
through Ansible or saved in this repository.

Git setup is optional and separate from provisioning. Routine provisioning never
prompts for credentials or changes commit identity. To adjust identity or sign
in later, run `setup-git` again. Your Mac's Git settings are not copied into the
guest automatically.

Run `dev-doctor` in the guest after provisioning or when troubleshooting. It
reports tool versions, the available managed Python, disk space, pending reboots,
the effective security-update policy and timer status, Git identity, and GitHub
API authentication. It does not install tools, modify configuration, or repair
anything. The GitHub check needs network access and does not print tokens. Git
identity reflects repository overrides if you run it inside a repository.
Missing tools, a pending reboot, disk usage of at least 90%, inactive update
timers, or missing daily-update/reboot-prevention settings cause a nonzero exit;
optional Git identity/authentication notices do not.

For a new project inside the guest:

```bash
uv init --python 3.15 my-project
cd my-project
uv add requests
uv add --dev ruff pytest
uv run python --version
uv run ruff check .
```

Commit `pyproject.toml`, `.python-version`, and `uv.lock`. Use `uv sync --locked`
to reproduce the locked dependencies in CI or another checkout. Virtual
environments (`.venv`) stay local and should not be committed.
Keep linting, testing, and type-checking tools in each project's development
dependencies instead of installing them globally in the VM. Once the project has
tests, run `uv run pytest`; add a type checker when the project needs one. CI
should select the same Python version and uv version, run `uv sync --locked`,
then run the same lint and test commands. Pin an exact Python patch in the
project's `.python-version` when that level of reproducibility is required.

After the initial OS upgrade, routine provisioning installs missing packages.
It pins uv and disables uv self-updates; change `uv_version` and reprovision
to update it.
A Python minor version installs the latest patch known to that uv release when
missing. Existing Python installations are kept; use `uv python upgrade 3.15`
for deliberate patch upgrades, or set `python_version` to an exact patch for
repeatable interpreter selection. Changing Python versions leaves older
installations and project version choices in place.

For a repository already available inside the guest, use `bash scripts/setup`
directly. This direct guest command still stops with manual restart instructions
when a reboot is required; automatic restart is handled by the host script.
Ansible options are forwarded by both scripts. `--check --diff` never triggers
an automatic restart and is most useful after the first successful setup; it
still bootstraps Ansible if missing, and a fresh guest cannot fully preview uv
and Python installation.

For manual validation after changing this repository, provision a disposable VM
with no extra Ansible options, run provisioning a second time, and check that the
tools remain usable without an unnecessary restart. Run `dev-doctor`, exercise
GitHub sign-in if needed, and back up and restore a project containing both
committed and untracked files. Also verify `--check --diff` does not restart the
VM. Use the host's bundled Bash for these checks to cover macOS Bash 3.2.
