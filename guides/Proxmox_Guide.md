# Proxmox Guide

*(c) Copyright Clinton Webb*

Proxmox is a virtual infrastructure service (similar to vmware).

## Proxmox Stuff

<details>
<summary>Removing failed snapshot</summary>

----
When creating a backup and cancelling, or whatever reason and a snapshot is failing to be removed, can do something like:
_in this example, 102 is the vmid_
```
# login to the shell of the proxmox host the node is on
pct unlock 102
pct listsnapshot 102
pct delsnapshot 102 vzdump -force
pct listsnapshot 102
```
----
</details>
<details>
<summary>Removing a node from a cluster</summary>

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

