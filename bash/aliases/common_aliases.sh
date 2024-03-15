HISTCONTROL=ignoreboth
function hc() { history -c && history -w }
function sshk() { [[ -n $1 ]] && sed -i ${1}d ~/.ssh/known_hosts }
