# Proxmox Guide

*(c) Copyright Clinton Webb*

Proxmox is a virtual 


## Proxmox Stuff

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

