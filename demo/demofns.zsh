unready_shell() {
  local fnname=$0
  local i
  local -a fns=(${functions[(I)*ready_*]})
  local -a toremove=(${0} reready)
  local -a raliases
  fns=(${fns:|toremove})

  for i in $fns; do
    print -u2 "Removing fn ${(qqq)i}"
    unfunction $i
  done

  raliases=(${(k)aliases[(R)*ready*]})

  for i in $raliases; do
    print -u2 "Removing alias ${(qqq)i}"
    unalias $i
  done
}

reready() {
  unready_shell
  command pkill -f by-server
  command ready clobber
  yes | command gem uninstall ready || true
  command bundle exec rake clobber
  command bundle exec rake build
  command gem install \
    --conservative \
    --no-document \
    --no-update-sources \
    --local pkg/ready*
}