# Copyright 2024, Clinton Webb
# This script can be referenced in .bashrc or .bash_profile which will set the Prompt.
#
# Example:
# webbcl@server1-1 ~/work/clintwebb/misc (main)$
#
#  This is showing the current username and server, followed by the current directory and the current branch if the current directory is part of a git repo
#  It can also show some **** if the SSH agent isn't active.  This is very likely useful when using SSH protocol to sync.



function parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

function parse_git_branch_sshagent() {
  GG=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')

  if [[ -z "$GG" ]]; then
    if [[ -z "$SSH_AGENT_PID" ]]; then
      echo "(****)"
    fi
  else
    if [[ -z "$SSH_AGENT_PID" ]]; then
      echo "($GG ****)"
    else
      echo "($GG)"
    fi
  fi
}
if [[ $PROMPT_SSHAGENT =~ ^(y|Y)$ ]]; then
  export PS1="\u@\h \[\e[32m\]\w \[\e[91m\]\$(parse_git_branch_sshagent)\[\e[00m\]$ "
else
  export PS1="\u@\h \[\e[32m\]\w \[\e[91m\]\$(parse_git_branch)\[\e[00m\]$ "
fi
