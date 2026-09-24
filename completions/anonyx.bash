# SPDX-License-Identifier: GPL-3.0-or-later
# bash completion for anonyx
_anonyx() {
  local cur cmds modes apps
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  cmds="--enable --disable --restore --doctor --opsec --bridges --status --leaktest --newid --panic --exec --audit --watchdog --ram-only --mode --exit --bridge --force-fw --dry-run --no-install --json --quiet --fix --help --version"
  apps="apt git ssh curl wget nmap"
  modes="strict paranoid transparent"
  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return 0
  fi
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  if [[ "$prev" == "--mode" ]]; then
    COMPREPLY=( $(compgen -W "$modes" -- "$cur") )
    return 0
  fi
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$apps" -- "$cur") )
    return 0
  fi
}
complete -F _anonyx anonyx
complete -F _anonyx Anonyx.sh
