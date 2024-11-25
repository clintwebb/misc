# Copyright 2024, Clinton Webb
# This script can be referenced in .bashrc or .bash_profile which will set the Prompt.
#
# Example View:
# webbcl@server1-1 ~/work/clintwebb/misc (main)$
#
#  This is showing the current username and server, followed by the current directory 
#  and the current branch if the current directory is part of a git repo
#
#  It can also show some **** if the SSH agent isn't active.  
#  This is very likely useful when using SSH protocol to sync.
#
# Examples for .bashrc:
#   # This will show the current branch if in a git repo (but will not show warning if ssh-agent not set)
#   source ~/work/clintwebb/misc/bash_show_repo/bash_show_repo.sh
#
#   # This will show '****' in the prompt if ssh-agent not set (if set, it will not show anything extra)
#   PROMPT_SSHAGENT=y
#   source ~/work/clintwebb/misc/bash_show_repo/bash_show_repo.sh

function parse_git_branch() {
  if git status 2> /dev/null|grep -q 'modified:'; then
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1 !!)/'
  else
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1 )/'
  fi
}

function parse_git_branch_sshagent() {
  local HH=
  git status 2> /dev/null|grep -q 'modified:' && HH=' !!'
  local GG=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')

  if [[ -z "$GG" ]]; then
    if [[ -z "$SSH_AGENT_PID" ]]; then
      echo "(****$HH)"
    fi
  else
    if [[ -z "$SSH_AGENT_PID" ]]; then
      echo "($GG ****$HH)"
    else
      echo "($GG$HH)"
    fi
  fi
}
if [[ ${PROMPT_SSHAGENT,,} =~ ^(y|yes|1|true)$ ]]; then
  export PS1="\u@\h \[\e[32m\]\w \[\e[91m\]\$(parse_git_branch_sshagent)\[\e[00m\]$ "
else
  export PS1="\u@\h \[\e[32m\]\w \[\e[91m\]\$(parse_git_branch)\[\e[00m\]$ "
fi
