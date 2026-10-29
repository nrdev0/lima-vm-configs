# Keep user-installed tools available to interactive and SSH command sessions.
typeset -U path PATH
path=("$HOME/.local/bin" $path)
export PATH
