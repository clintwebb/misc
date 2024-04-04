HISTCONTROL=ignoreboth
function hc() { history -c && history -w; }
function sshk() { [[ $1 =~ "^[0-9]+$" ]] && sed -i ${1}d ~/.ssh/known_hosts; }
function sudos { while true; do sudo sleep 60; done }
function ddtmp { [[ ! -d $HOME/tmp ]] && mkdir $HOME/tmp; [[ ! -d $HOME/tmp/$(date +%F) ]] && mkdir $HOME/tmp/$(date +%F); pushd $HOME/tmp/$(date +%F); }
