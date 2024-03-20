# Bash Guide

This document is not a full and deep bash tutorial, but describes the common methods that I use.
Some items will be used frequently, but also some items will be very useful but only required rarely, so good to document to recall and re-use.

<details>
<summary>Checking for multiple possibilities in a variable</summary>

```
# This basically uses a Regex comparison
if [[ "$1" =~ ^(development|test|uat|production)$ ]]; then
  echo "Matched!"
else
  echo "Nothing Matched"
fi
```
</details>
