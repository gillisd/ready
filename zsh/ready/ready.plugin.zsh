# run in subshell so that it can do its thing without tampering with fpath, PATH, other globals

() {
  setopt pipefail

  zmodload zsh/files
  zmodload -m -F zsh/files b:zf_\*

  local __FILE__=${${(%)${:-%x}}:A}
  local __DIR__=${__FILE__:h:A}
  typeset -gx READY_COMPLETIONS_DIR=${__DIR__:h}/site-functions
  typeset -gx READY_PREFIX=${READY_PREFIX:-/tmp/ready}
  typeset -gx READY_LOG_PATH=${READY_LOG_PATH:-${READY_PREFIX}/ready.log}
  typeset -gx READY_DEBUG=${READY_DEBUG:-0}
  typeset -gx READY_SRC_DIR=${__DIR__:h:h}
  typeset -gx READY_ZSH_SRC_DIR=${__DIR__}
  typeset -gx READY_SOCK_PATH=${READY_SOCK_PATH:-${READY_PREFIX}/ready.sock}

  if ! [[ -d $READY_PREFIX ]]; then
    zf_mkdir -p $READY_PREFIX
  fi

  fpath+=($__DIR__/functions $__DIR__/functions/ready $READY_COMPLETIONS_DIR)

  autoload -Uz readyup readyinit __ready_debug __ready_print

  local rc=1

  if [[ -S $READY_SOCK_PATH ]]; then
    __ready_debug debug "Sock found, returning"
    readyinit

    return
  fi

  __ready_debug debug "Sock not found, creating"

  if ! (( $+parameters[RBENV_SHELL] )); then
    __ready_debug warn "RBENV_SHELL not detected"
  fi

  readyup; rc=$?

  if (( rc )); then
    autoload -Uz __ready_print
    __ready_print -u2 -c red "Ready failed to initialize. Check %B${READY_LOG_PATH}%b for more info"
  fi

  return $rc
}
