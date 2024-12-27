# arki

----

This is a tool that is used for a unique situation.   Essentially to restructure files and folders based on some original source, but to be hard-linked and restructured in the archived source. 

The main purpose is to rebuild and recover.  In this case, the archived files are the some but in completely different folder structure than the original.  

This script iterates through the original source, making note of the filenames.   It then iterates over the archived section, creates the original folder structure and sets hard-links to files in the archive that match the original structure, without affecting the archived content.

Any file that is in the archived content, but not found in the original, will also be hardlinked to some other folder to be reviewed.

At the end, it will have a remaining list of files that are in the archive, and the ones in the orginal that are not in the archive.

An operation can also occur that can clean-up anything in the orginal that is in the archive.


