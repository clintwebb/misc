# Grabber

Grabber can be used to gather information about files on one server, and compare against another.  
This can be used to find differences.

```
# Copy the script to the first server and do
./grabber.sh grab server1 /data

# this will create a grabber.db file...
# copy the script, and that grabber.db file over to the other server, and do similar thing
./grabber.sh grab server2 /data

# Now you can compare the differences
./grabber.sh compare server1 server2
```

There are other options available too, where it can verify the contents match (md5sum).

