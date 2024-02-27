# Copyright 2024, Clinton Webb
This script can be referenced in .bashrc or .bash_profile which will set the Prompt.

Example:
webbcl@server1-1 ~/work/clintwebb/misc (main)$

This is showing the current username and server, followed by the current directory and the current branch if the current directory is part of a git repo
It can also show some **** if the SSH agent isn't active.  This is very likely useful when using SSH protocol to sync.

In the .bashrc, can simply do

export PROMPT_SSHAGENT=y
source tools/bash_show_repo.sh
