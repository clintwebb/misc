# do_ip

This is a simple script which is intended to be run regularly on a home system to determine the IP that is provided by the ISP.
DNS records in DigitalOcean are then updated to point to the new home address.

This is normally used where someone is wanting an external site/service to be able to talk to their home network (even without a static IP allocated).

> [!IMPORTANT]
> You can only do this with registered and owned domains existing in DigitalOcean's services.

> [!NOTE]
> To generate an access token, visit https://docs.digitalocean.com/reference/api/create-personal-access-token/

In `/etc/do_ip.conf` need the following variables set

```
# /etc/do_ip.conf
export DIGITALOCEAN_ACCESS_TOKEN='abc...123'
export DO_DOMAIN=example.com
export DO_AREC=home1
```

This will result in `home1.example.com` pointing to your non-static home IP address.

You can setup a systemd service and timer to periodically perform the functionality.

Setup a service...
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

Setup a timer to trigger the above service (since the timer doesn't specifically mention a service name, the timer will trigger the service with the same name)
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

