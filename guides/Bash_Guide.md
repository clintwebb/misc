# Bash Guide

This document is not a full and deep bash tutorial, but describes the common methods that I use.
Some items will be used frequently, but also some items will be very useful but only required rarely, so good to document to recall and re-use.


<details>
<summary>Outputting multiple items</summary>

----
Often might need to handle something with multiple number... like
```
item1 item2 item3
```

To do that... can do something like `echo "item{1..3}"`
----
</details>
<details>
<summary>Assigning output to a variable.</summary>

----
The power of linux/bash scripting is being able to integrate command-line tools into it easily and simply.

If you want to run a command, and put the output in a variable, which can then be manipulated and used:
```
FILES=`ls`
echo $FILES
```

In the above example, it runs the 'ls' command and the output is put in $FILES.   Which you can then use a for loop to go through and process.  Note that the ls command is in back-ticks.

An alternative way of doing it is using $() instead, which does essentially the same thing.
```
FILES=$(ls)
echo $FILES
```
----
</details>


<details>
<summary>Checking for multiple possibilities in a variable</summary>

----
```
# This basically uses a Regex comparison
if [[ "$1" =~ ^(development|test|uat|production)$ ]]; then
  echo "Matched!"
else
  echo "Nothing Matched"
fi
```
----
</details>

#### Extra Notes

This section contains things not specific about Bash, but often used in Bash environments

<details>
<summary>Tar split into multiple files.</summary>

----
Often used when the tar-zip file will be larger than the transport storage available, and needs to be split into multiples.

To archive/compress:
```
tar cvzf - dir/ | split --bytes=49m - backup.tar.gz.
```

Once all have been delivered to the target location, can extract them:
```
cat backup.tar.gz.* | tar xzvf -
```

----
</details>
