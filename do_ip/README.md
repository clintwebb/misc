# do_ip

This is a simple script which is intended to be run regularly on a home system to determine the IP that is provided by the ISP.
DNS records in DigitalOcean are then updated to point to the new home address.

This is normally used where someone is wanting an external site/service to be able to talk to their home network (even without a static IP allocated).

NOTE: You can only do this with registered and owned domains existing in DigitalOcean's services.

In `/etc/do_ip.conf` need the following variables set

```
DIGITALOCEAN_ACCESS_TOKEN='abc...123'
DO_DOMAIN=example.com
DO_AREC=home1
```

This will result in `home1.example.com` pointing to your non-static home IP address.

You can setup a systemd service and timer to periodically perform the functionality.


``` 
# /etc/systemd/system/do_ip.service
[Unit]
Description=Home1 IP

[Service]
Type=simple
ExecStart=/opt/do_ip/do_ip.sh

[Install]
WantedBy=multi-user.target
```

```
# /etc/systemd/system/do_ip.timer
[Unit]
Description=Trigger Timer for IP management

[Timer]
#OnCalendar=01:00:00
OnCalendar=*-*-* *:00,05,10,15,20,25,30,35,40,45,50,55:00

[Install]
WantedBy=multi-user.target
```

