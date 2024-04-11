# Proxmox Guide

*(c) Copyright Clinton Webb*

Proxmox is a virtual infrastructure service (similar to vmware).
_NOTE that this is not complete documentation, just things that I have found useful or needed over time._

## Proxmox Tools

<details><summary><b>pct</b> - for managing containers.</summary>

* <details><summary>pct unlock</summary>

  ----
  if a container is locked, when it shouldnt be (because a task failed), this can be used to unlock it.

  ```
  # example to unlock container 102
  pct unlock 102
  ```
  ----
  </details>
</details>
  


## Proxmox General Guidance

<details><summary>Removing failed snapshot</summary>

----
When creating a backup and cancelling, or whatever reason and a snapshot is failing to be removed, can do something like:

```
# login to the shell of the proxmox host the node is on
# in this example, 102 is the vmid of the node we having problems with
pct unlock 102
pct listsnapshot 102
pct delsnapshot 102 vzdump -force
pct listsnapshot 102
```
----
</details>
<details><summary>Removing CT Volumes that exist but cannot be removed from the GUI. </summary>

----
In the GUI the volumes are presented, but it does not let you delete them, because they attached to a node that exists.  The GUI suggests to go into the Resources tab for that node and remove them there... however, those volumes are not showing up in that tab.
```
# list the volumes that are on the 'local-lvm' storage (as an example)
pvesm list local-lvm

# Now can remove the invalid volume 
pvesm free local-lvm:vm-102-disk-4
```
----
</details>
<details><summary>Removing a node from a cluster</summary>

----
When removing a node from the cluster, it is imperative to:
* ensure that interface is to another node.
* ensure that no Replication is configured on the node
* migrate any vm's that are on the node that are remaining
* shutdown the node that is being removed
* login to console of another node, and `pvecm delnode _nodename_`
   * if quorum is not met, can try setting to only require 1 vote `pvecm expected 1`

----
</details>

