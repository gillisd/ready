#!/usr/bin/env zsh
emulate -L zsh
setopt extendedglob

zmodload zsh/zutil

local -A opts
zparseopts -D -E -F -M -A opts \
  - \
  -style: \
  -reg \
  -preview \
  -glow \
  -rif \
  f:=-format \
  -format:

(( $? == 0 )) || return 1

zmodload -F zsh/files b:zf_mkdir
zmodload zsh/mapfile
mapfile[/tmp/fzf/state//reg]=""

typeset -gx RIF=$(( $+opts[--rif] ))
typeset -gx RI_REG=$(( $+opts[--reg] ))
typeset -gx FORMAT=${${opts[--format]:-markdown}#=}
typeset -gx GLOW=$(( $+opts[--glow] ))
typeset -gx STYLE=${${opts[--style]:-dark}#=}
typeset -gx TIMEFMT='%U user %S system %P cpu %*E total'
typeset -gx _RI_SELF=${0:A}
typeset -gx _RI_FIFO=$(mktemp -u)
typeset -gx _RI_FD_RW _RI_FD_R

typeset -g FZFX=~/repos/vault/wip/fzfx.sh

local script_dir=${0:A:h}
local rif=$script_dir/rif2
local formatter=$script_dir/formatter.rb
local ready_build=/tmp/ready/builds.zwc

if [[ -f $ready_build ]]; then
  fpath+=(${ready_build:P})
  autoload -Uz ${ready_build:P}
else
  print -u2 -P "%F{yellow}Warning: ready build zwc not found"
  exit 1
fi

if ! [[ -f $formatter ]]; then
  print -u2 "%F{red}%BError:%b Cannot locate %Bformatter.rb%b%f"
  return 1
fi

mkfifo $_RI_FIFO

exec {_RI_FD_RW}<>$_RI_FIFO
exec {_RI_FD_R}<$_RI_FIFO

trap "exec {_RI_FD_RW}>&- {_RI_FD_R}>&-; rm -f $_RI_FIFO" EXIT INT TERM

glow() {
  emulate -L zsh
  setopt extendedglob
  CLICOLOR_FORCE=1 command glow --style $STYLE $@
}

display() {
  emulate -L zsh

  if ! (( GLOW )); then
    command cat
  else
    $script_dir/by $formatter \
    | gawk '
		/`{3}ruby/{block=1; print; next}
		/`{3}/{block=0; print; next}
		block==1{gsub(/^    /,"")}
		{print}
' | glow
  fi
}

preview() {
  emulate -L zsh
  setopt extendedglob
  local rc
  local -a ri_args=(--format=$FORMAT)
  local -a rif_args=(--forcebat)
  local -a rif2_args

  if (( RIF )); then
    autoload -Uz +X rif
    rif_args+=(${@:#-*})
    rif2_args+=(${@:#-*})
    $rif ${(z)rif2_args}; rc=$?

    if (( rc != 0 )); then
      print -u2 -P "%F{yellow}No matches found for %B$@%b%f"
    fi
    return $rc
  fi

  {
    if (( $RI_REG )); then
      command ri $ri_args $@
    else
      # normally would pass ri_args here but args present keeps triggering Test::Unit
      $script_dir/ready_ri $@
    fi
  } | display
}

printrez() {
  local arr_name=${1:?}
  local item=${${(P)arr_name}[-1]}
  local rc
  local -a lines
  ($script_dir/ready_ri --list $item  2>/dev/null) \
    | {
    read line && lines+=($line)
    read line && lines+=($line)
    read line && lines+=($line)
    read line && lines+=($line)
    if [[ $lines =~ '--list' ]]; then
      $script_dir/ready_ri "$item#" 2>/dev/null
    else
      print -r -l -- $lines
      cat
    fi
  } | $script_dir/finder.sh
}

local -a stack
if (( $+opts[--preview] )); then
  preview $@
  return $?
else
  while true; do
    if (( $#stack == 0 )); then
      result=$( printrez stack)
      rc=$?

      if [[ -z $result ]]; then
        break
        return $rc
      fi
      stack+=($result)
    else
      result=$(printrez stack)

      rc=$?

      if (( rc == 0 )) && (( ${#${result#[A-Z]}} != $#result )); then
        stack+=($result)
        continue
      else
        stack=(${stack[1,-2]})
      fi
    fi
  done
fi
