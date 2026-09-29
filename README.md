# lima-vm-configurations
Configurations for https://lima-vm.io/ virtual machines

`dev-default-x86_64.yaml` runs [scripts/install-zsh.sh](scripts/install-zsh.sh)
during system provisioning to install zsh and make it the VM user's default
login shell. The configured `user.shell` remains Bash
for initial startup because Lima requires that shell to exist in the guest
image. Provisioning runs on each boot and only installs zsh if it is missing.

[scripts/install-dev-tools.sh](scripts/install-dev-tools.sh) installs the baseline
developer tools: `git`, `curl`, `ca-certificates`, `zip`, `unzip`, `xz-utils`,
`build-essential`, `pkg-config`, `jq`, `ripgrep`, `less`, `vim`, and `rsync`.
It checks package status on each boot and only runs apt when packages are missing.

Lima resolves script paths relative to the YAML file and embeds their contents
when creating an instance. Changing this YAML or its scripts does not update
an existing VM. To switch an existing Ubuntu VM, run inside
the guest:

```sh
sudo apt-get update
sudo apt-get install -y zsh
sudo chsh -s /usr/bin/zsh "$USER"
```

Open a new session to use the new shell. See the
[Lima shell documentation](https://lima-vm.io/docs/usage/#user-shell).
