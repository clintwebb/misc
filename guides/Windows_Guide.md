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

```
Test-NetConnection -computername example.com -Port 443
```
</details>
<details>
<summary>Create DNS Entries (should be on the domain controller managing dns)</summary>

```
# 'A'
Add-DnsServerResourceRecordA  -ZoneName "example.com" -CreatePtr -IPv4Address "10.1.2.118"   -Name "www1"
Add-DnsServerResourceRecordA  -ZoneName "example.com" -CreatePtr -IPv4Address "10.1.2.119"   -Name "www2"
 
# 'CNAME'
Add-DnsServerResourceRecordCName -Name "www" -HostNameAlias "www1.example.com." -ZoneName "example.com"
```
</details>
<details>
<summary>Execute powershell commands on remote servers</summary>

[doco](https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/running-remote-commands?view=powershell-7.4)
```
Invoke-Command -ComputerName Server01, Server02 -ScriptBlock {Get-UICulture}
```
</details>
