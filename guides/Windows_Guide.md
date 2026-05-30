# Windows Guide

Windows is often very different to Linux.

## Misc Windows Stuff

<details>
<summary>Viewing Logon/Logoff History</summary>

----
see [answer](https://answers.microsoft.com/en-us/windows/forum/all/i-want-to-view-login-history-for-the-last-week/5fe01b49-0570-47c1-bf1f-edf2efed8202)

You can use the **Event Viewer** to see this information.

1. Open **Event Viewer**.
2. In the Event Viewer, in the **Navigation Pane** on the **left side**.

   a. Expand **Applications and Services Logs** (might take a few minutes to load) / **Microsoft** / **Windows** / **User Profile Service**

   b. Click the **Operational** folder.

4. At the top of the **Center section**, you will see the Events list sorted by Date/Time and Event ID.

   a. The **Event ID 2** is a **Logon** and the **Event ID 4** is a **Logoff**.

5. Select one of these events and, in the bottom pane, you will see the information showing the User Name that was Logged on or Logged Off on that date at that time.

   a. Scroll down to the Date and Time that you are looking for.

Can also use Filters....

----
</details>

<details>
<summary>Obtain installed Windows Key via Linux</summary>

----
Install chntpw tool.

```
sudo apt install chntpw
```

To look into the relevant registry file mount the Windows disk and open it like so:

```
chntpw -e Windows/System32/config/SOFTWARE
```

Now to get the decoded DigitalProductId enter this command:

```
dpi \Microsoft\Windows NT\CurrentVersion\DigitalProductId
```
----
</details>

## Powershell Stuff

<details>
<summary>Test Network connection (like telnet)</summary>

----
```
Test-NetConnection -computername example.com -Port 443
```

----
</details>
<details>
<summary>Create DNS Entries (should be on the domain controller managing dns)</summary>

----
```
# 'A'
Add-DnsServerResourceRecordA  -ZoneName "example.com" -CreatePtr -IPv4Address "10.1.2.118"   -Name "www1"
Add-DnsServerResourceRecordA  -ZoneName "example.com" -CreatePtr -IPv4Address "10.1.2.119"   -Name "www2"
 
# 'CNAME'
Add-DnsServerResourceRecordCName -Name "www" -HostNameAlias "www1.example.com." -ZoneName "example.com"
```

----
</details>
<details>
<summary>Execute powershell commands on remote servers</summary>

----
[doco](https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/running-remote-commands?view=powershell-7.4)
```
Invoke-Command -ComputerName Server01, Server02 -ScriptBlock {Get-UICulture}
```

----
</details>
<details>
<summary>Create thumbdrive to install windows ISO</summary>

----

This info was obtained from some website doco.... 


```
# my USB stick was sdb, check yours with lsblk and adjust
sudo fdisk /dev/sdb

Command (m for help): o
Created a new DOS (MBR) disklabel with disk identifier ...

Command (m for help): n
Partition type
p   primary (0 primary, 0 extended, 4 free)
e   extended (container for logical partitions)
Select (default p):
Using default response p.
Partition number (1-4, default 1):
First sector (2048-15974399, default 2048):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-15974399, default 15974399): +1024M
Created a new partition 1 of type 'Linux' and of size 1 GiB.

Command (m for help): t
Selected partition 1
Hex code or alias (type L to list all): uefi
Changed type of partition 'Linux' to 'EFI (FAT-12/16/32)'.

Command (m for help): n
Partition type
p   primary (1 primary, 0 extended, 3 free)
e   extended (container for logical partitions)
Select (default p):
Using default response p.
Partition number (2-4, default 2):
First sector (2099200-15974399, default 2099200):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2099200-15974399, default 15974399):
Created a new partition 2 of type 'Linux' and of size 6.6 GiB.

Command (m for help): t
Partition number (1,2, default 2):
Hex code or alias (type L to list all): 7
Changed type of partition 'Linux' to 'HPFS/NTFS/exFAT'.

Command (m for help): w
The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.

# commands outside fdisk

sudo mkfs.vfat -F 32 -n BOOT /dev/sdb1

sudo mkfs.ntfs --quick --label INSTALL /dev/sdb2

# checking what's now on the USB stick
lsblk --fs
...
sdb
├─sdb1 vfat   FAT32 BOOT
└─sdb2 ntfs         INSTALL

# copying the files manually based on Oleg's answer
# I used /mnt/temp_iso for mounting Microsoft's ISO file and /mnt/temp for mounting BOOT and INSTALL partitions sequentially

# ISO
sudo mount Win10.iso /mnt/temp_iso

# BOOT partition
sudo mount /dev/sdb1 /mnt/temp
# from Oleg's answer:
# Copy the content except "sources" directory from Windows ISO to "BOOT" partition
# Create "sources" directory on "BOOT" partition and copy boot.wim file to the "sources" directory
sudo umount /mnt/temp

# INSTALL partition
sudo mount /dev/sdb2 /mnt/temp
# from Oleg's answer:
# Copy all content from Windows ISO to "INSTALL" partition

# DONE
sudo umount /mnt/temp
sudo umount /mnt/temp_iso
```

----
</details>

