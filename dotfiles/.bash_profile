# Lima uses Bash for bootstrap. Interactive login sessions switch to zsh after
# provisioning; noninteractive Bash scripts continue to run in Bash.
if [[ -r "$HOME/.profile" ]]; then
    source "$HOME/.profile"
fi

if [[ $- == *i* && -x /bin/zsh ]]; then
    export SHELL=/bin/zsh
    exec /bin/zsh -l
fi
