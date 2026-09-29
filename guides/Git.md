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
