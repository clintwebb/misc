# Git Guides

<details>
<summary>Create new branch</summary>

----
Using `example` as the name of the branch to create.
```
# Make sure currently in the branch wanting to go from
git checkout main

# create new 'example' branch from main
git checkout -b example
```
----
</details>


<details>
<summary>Removing a branch (local and remote)</summary>

----
Using `example` as the name of the branch
```
git branch -d example
git push origin --delete example
```
----
</details>


<details>
<summary>Fixing a mistake of pushing a branch</summary>

----
If there is a situation where have another branch (Using `example` as the name of the branch), and accidentally merge it into the main branch and push it.  
Dont want that branch merged into main yet, so need to remove that change.
```
# To find the key of the previous branch (before the merge)
git log --online
```
Which gives a result like this
```
$ git log --oneline
f8de003 (HEAD -> main, origin/main, origin/HEAD) Merge branch 'example' into main
c364785 (example) Testing teams chat notice
3864cd3 (airlock) minor change
... 
```
Need to pick the previous hash before that wrong merge.  In this example, it is `3864cd3`
```
# and then revert it.
git revert -m 1 3864cd3

# and then push it
git push
```
----
</details>
