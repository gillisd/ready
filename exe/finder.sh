#!/usr/bin/env sh

FZFX="$HOME/repos/vault/wip/fzfx.sh"

exec "$FZFX" \
  --ansi \
  --reverse \
  --preview='preview {}' \
  --bind='change:first' \
  --bind='focus:bg-transform-preview-label(print_timing)' \
  --bind='start:execute-silent(initialize)+bg-transform-footer(flip_toggle glow; print_mode)+refresh-preview' \
  --bind='alt-m:execute-silent(change_mode)+bg-transform-footer(print_mode)+refresh-preview' \
  --bind='alt-g:execute-silent(toggle_glow)+bg-transform-footer(print_mode)+refresh-preview' \
  --bind='tab:execute-silent(toggle_source)+refresh-preview' \
  --preview-window='70%,wrap' \
--inject '
      initialize() {
				create_toggle rif
	      create_toggle glow

	      if (( RI_REG )); then
		      state_set reg 1
	      else
		      state_set reg 0
	      fi
      }

      print_timing() {
	zmodload zsh/system
	sysread -i ${_RI_FD_R} -o 1
      }

      print_mode() {
				emulate -L zsh
				local mode

	      if _is_reg; then
		      mode="%BNORMAL%b"
	      else
		      mode="%B%F{green}RIZZ%f%b"
	      fi

				if get_toggle glow; then
					mode="$mode + %F{magenta}glow%f"
				fi
				print -P -- ${mode}
      }

      toggle_glow() {
	      flip_toggle glow
      }

		  toggle_source() {
				flip_toggle rif
			}

      change_mode() {
	      if _is_reg; then
	        state_set reg 0
	      else
	        state_set reg 1
	      fi
      }

      preview() {
          if _is_reg; then
						RI_REG=1
					else
						RI_REG=0
					fi

          local -a args=(--preview)

					if (( RI_REG )); then
						args+=(--reg)
					fi

					if get_toggle glow; then
						args+=(--glow)
					fi

					if get_toggle rif; then
						args+=(--rif)
					fi

					{ time $_RI_SELF --style $STYLE -f $FORMAT ${(z)args} -- $@ 2>&1 } 2>&$_RI_FD_RW
				}

      _is_reg() {
	      integer value=$(state_get reg)
	      if (( value )); then
		      return 0;
	      else
		      return 1
	      fi
      }
      '
