# Copyright 2024, Clinton Webb
This script can be referenced in .bashrc or .bash_profile which will set the Prompt.

Example:
webbcl@server1-1 ~/work/clintwebb/misc (main)$

This is showing the current username and server, followed by the current directory and the current branch if the current directory is part of a git repo.

It can also show some **** if the SSH agent isn't active.  This is very likely useful when using SSH protocol to sync.

As an example, in the .bash_profile, can simply do (assuming the script has been placed in ~/tools/):
```
# This will show the current branch if in a git repo (but will not show warning if ssh-agent not set)
source ~/tools/bash_show_repo/bash_show_repo.sh
```
Alternatively, if you want it to show if ssh-agent not set:
```
# This will show '****' in the prompt if ssh-agent not set (if set, it will not show anything extra)
PROMPT_SSHAGENT=y
source ~/tools/bash_show_repo/bash_show_repo.sh
```
