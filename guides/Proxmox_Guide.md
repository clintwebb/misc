# Proxmox Guide

*(c) Copyright Clinton Webb*

Proxmox is a virtual infrastructure service (similar to vmware).

## Proxmox Stuff

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
   * if quorum is not met, can try setting to only require 1 vote `pvecm expect 1`

----
</details>

