#!/bin/bash
# Author: Clinton Webb, 2024
# (c) Copyright 2024, Clinton Webb.  All rights reserved.

# This script is used to gather file system information in order to compare with other systems.
# It is intended to be run on each target machine with a label, and the information is stored 
# in an sqlite db file which will need to be moved between servers.

# ./grabber.sh <command> <env> [location]
# For example:
#    ./grabber.sh get uat /opt/broker

# It will go through all the files in the location and store information about it.  
# It can even be told to get md5sum totals of the files in order to compare contents... 
# however, that would not be recommended in a location with large files, or large number of files.

# Likely commands:
#  get     : get all the generic info (permissions, ownership, filename, size)
#  md5     : similar to 'get' but also does an md5sum on each file (permissions, ownership, filename, size, md5sum)
#  compare : compare differences between 2 specified environments.


DB_FILE=${DB_FILE:-grabber.db}
#DEBUG=1
#DEBUG=2

function usage() {

  cat << EOF

Grabber
-------

Grabber is commonly used to check the contents of one system against another system.
But it does have some additional functionality that is useful in different situations.

Generally you would copy the script over to the first target server, and run 'grabber.sh init'
Then you would run the script on that server (in this example, we are calling it 'one')
  Example:   grabber.sh get one /data

This will grab all the info of all files in that /data folder and store it in a grabber.db file.
Then you would copy the script, and that grabber.db file to the other server (which we will call 'two')
And then do a similar thing.
  Example:   grabber.sh get two /data



Commands:

  init
        initialise the database.
        Example:
          grabber.sh init

  get
        get the contents of the system
        Example:
          grabber.sh get one /data

  md5
        Obtain content data (md5sum) to be able to determine differences.

  compare
        Compare the difference between one environment and another.
        It will provide the information, which includes Owner, Group and Permissions.

  owner
        Similar to compare, but doesn't look at the Permissions.
        Only really useful if checking ownership.

  compare_md5
        Only works if 'md5' was used to gather the information.
        But is useful to verify content is the same or different.

  fix
        Will output script content to fix the second environment to match the first environment indicated.
        Example:
          grabber.sh fix one two

  find
        Only used with md5, allows you to find a file in any environment source.
        Example:
          grabber.sh find /data/thisfile.txt
        This will do an md5sum on /data/thisfile.txt and will then look throught the
        database to find any files that have the same content.

  remove_dup
        Will output scripting to remove duplicate files in the second environment that
        also exist in the first environment.

EOF
  exit 1
}



# This query function will allow us to perform an operation, but wait for 20 seconds if the file is locked.
# without a setting like this, if there is another operation on the file occuring at the same time, it will fail. 
# 
# NOTE: Older versions of sqlite3 (which is the latest one from Redhat7) does not handle some things quite as nice, 
#       so setting the function based on at least that version number.  Some alterations may need to be done for 
#       other specific version.
if [[ $(sqlite3 --version | awk '{ print $1 }' | awk -F. '{ print ($1*10000)+($2*100)+($3) }') -le 30717 ]]; then

  # This query function will allow us to perform an operation.  
  # This was modified from the previous version, because it wasn't working quite right on an example legacy redhat7 server (it kept on outputting an extra blank line)
  # Investigated.  Seems to be an issue with older versions (like in Redhat 7 or older) which causes an extra line to be output, which needs to be trimmed.
  function query() {
    [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2
    sqlite3 -init <(echo ".timeout 20000") $DB_FILE "$1" 2>/dev/null|tail -n +2
  }
  function query_ro() {
    [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2
    sqlite3 -readonly -init <(echo ".timeout 20000") $DB_FILE "$1" 2>/dev/null|tail -n +2
  }
else
  function query() {
    [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2
    sqlite3 -init <(echo ".timeout 20000") $DB_FILE "$1" 2>/dev/null
  }

  function query_ro() {
    [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2
    sqlite3 -readonly -init <(echo ".timeout 20000") $DB_FILE "$1" 2>/dev/null
  }
fi

# This function is used when inserting into a table, and wanting the new RowID (primary key) returned. 
function query_insert() {
  echo $(query "$1; SELECT last_insert_rowid();")
}


function create_db() { 
   # Initial database schema.  Once there is data in the file, any changes will need to be done differently. 
   cat > $DB_FILE.sql <<EOF 
CREATE TABLE Environments ( 
 EnvID INTEGER UNIQUE PRIMARY KEY, 
 Name STRING UNIQUE
); 

CREATE TABLE Settings (
  Name STRING,
  Value STRING
);
INSERT INTO Settings (Name, Value) VALUES ('Version', '1');

CREATE TABLE Files ( 
 FileID INTEGER UNIQUE PRIMARY KEY, 
 NameHash STRING NOT NULL,
 EnvID INTEGER NOT NULL,
 Dir INTEGER,
 Perms STRING,
 Owner STRING,
 Groups STRING,
 Filename STRING NOT NULL,
 Size  INTEGER,
 Md5hash STRING,
 Process INTEGER
);

EOF

   sqlite3 $DB_FILE < $DB_FILE.sql 
   local RESULT=$? 
   rm $DB_FILE.sql

   return $RESULT 
} 


function get_setting() {
  query_ro "SELECT Value FROM Settings WHERE Name='$1';"
}

function get_EnvID() {
  query_ro "SELECT EnvID FROM Environments WHERE Name='$1';"
}

function grab() {
  CENV=$1
  TARG=$2
  MD5=$3

  if [[ -z "$CENV" ]]; then
    echo "Failed.  Environment required"
    exit 1
  fi

  if [[ -z "$TARG" ]]; then
    TARG="."
  fi

  if [[ ! -d "$TARG" ]]; then
    echo "Target directory doesn't exist."
    exit 1
  fi

  local EnvID=$(get_EnvID $CENV)
  if [[ $EnvID -le 0 ]]; then
    echo "Environment '$CENV' doesn't exist.  Creating."
    EnvID=$(query_insert "INSERT INTO Environments (Name) VALUES ('$CENV');")
  fi

  if [[ $MD5 == 'md5' ]]; then
    find -L $TARG -exec $0 process_md5 $EnvID '{}' \;
  else
    find -L $TARG -exec $0 process $EnvID '{}' \;
  fi
}

function process() {
  local xEnvID=$1
  local FILE="$2"
  echo "Processing '$FILE'"

  local xNameHash=$(echo "$FILE"|md5sum|awk '{print $1}')

  local xDir=0
  if [[ -d "$FILE" ]]; then
    xDir=1
  fi

  local OUTP=$(ls -ld "$FILE")

  local xPerms=$(echo "$OUTP"|awk '{print $1}')
  local xOwner=$(echo "$OUTP"|awk '{print $3}')
  local xGroups=$(echo "$OUTP"|awk '{print $4}')
  local xSize=$(echo "$OUTP"|awk '{print $5}')

  [[ $DEBUG ]] && echo "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0);"
  xFileID=$(query_insert "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0);")
  [[ $DEBUG ]] && echo "FileID: $xFileID"
}

function process_md5() {
  local xEnvID=$1
  local FILE="$2"
  echo "Processing '$FILE'"

  local xNameHash=$(echo "$FILE"|md5sum|awk '{print $1}')

  local xDir=0
  if [[ -d "$FILE" ]]; then
    xDir=1
  fi

  local OUTP=$(ls -ld "$FILE")

  local xPerms=$(echo "$OUTP"|awk '{print $1}')
  local xOwner=$(echo "$OUTP"|awk '{print $3}')
  local xGroups=$(echo "$OUTP"|awk '{print $4}')
  local xSize=$(echo "$OUTP"|awk '{print $5}')

  if [[ $xDir -ne 0 ]]; then
    [[ $DEBUG ]] && echo "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0);"
    xFileID=$(query_insert "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0);")
    [[ $DEBUG ]] && echo "FileID: $xFileID"
  else
    local xMD5hash=$(md5sum "$FILE"|awk '{print $1}')
    xFileID=$(query_insert "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process, Md5hash) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0, '$xMD5hash');")
    [[ $DEBUG ]] && echo "FileID: $xFileID"
  fi
}

function ginfo() {
  local Item=$1
  local FileID=$2

  >&2 echo "SELECT $Item FROM Files WHERE FileID=$FileID LIMIT 1;"
  query_ro "SELECT $Item FROM Files WHERE FileID=$FileID LIMIT 1;"
}


function compare() {
  if [[ -z "$2" ]]; then
    echo "ERROR.  Expect two environments to compare"
    exit 1
  fi

  local QQ="Owner,Groups,Perms"
  if [[ -n "$3" ]]; then
    QQ="$3"
  fi

  local EA=$(get_EnvID "$1")
  if [[ $EA -le 0 ]]; then
    echo "Environment '$1' not found"
    exit 1
  fi

  local EB=$(get_EnvID "$2")
  if [[ $EB -le 0 ]]; then
    echo "Environment '$2' not found"
    exit 1
  fi

  # First, we need to set the process flag for all files to 0.
  query "UPDATE Files SET Process=0"


  # First we process all the entries for the first environment, and compare the second environment.
  local AxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EA AND Process=0 LIMIT 1;")
  while [[ -n "$AxFileID" ]]; do
    local HASH=$(query_ro "SELECT NameHash FROM Files WHERE FileID=$AxFileID";)
    local FileName=$(query_ro "SELECT FileName FROM Files WHERE FileID=$AxFileID";)

    # Now look for the other file from the second environment that has the same name.
    [[ $DEBUG ]] && echo "SELECT FileID FROM Files WHERE EnvID=$EB AND NameHash='$HASH';"
    local BxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EB AND NameHash='$HASH';")
    if [[ $BxFileID -le 0 ]]; then
      echo "$1: $FileName missing on $2"
      query "UPDATE Files SET Process=1 WHERE FileID=$AxFileID"
    else

      local AxP=$(query_ro "SELECT $QQ FROM Files WHERE FileID=$AxFileID LIMIT 1;")
      local BxP=$(query_ro "SELECT $QQ FROM Files WHERE FileID=$BxFileID LIMIT 1;")

      if [[ $AxP != $BxP ]]; then
        echo -e "$FileName \t($AxP) ($BxP)"
      fi

      query "UPDATE Files SET Process=1 WHERE FileID=$AxFileID OR FileID=$BxFileID"

    fi

    AxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EA AND Process=0 LIMIT 1;")
  done


  # Now list all the times in the second environment that was not in the first.
  local BxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EB AND Process=0 LIMIT 1;")
  while [[ -n "$BxFileID" ]]; do
    local FileName=$(query_ro "SELECT FileName FROM Files WHERE FileID=$BxFileID";)

    echo "$2: $FileName missing on $1"
    query "UPDATE Files SET Process=1 WHERE FileID=$BxFileID"

    BxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EB AND Process=0 LIMIT 1;")
  done
}


# Fix will generate output that can essentially be scripted to fix things between the environments.
# The first argument is the source, the second is the destination (what should be fixed to match the source)
function fix() {
  if [[ -z "$2" ]]; then
    echo "ERROR.  Expect two environments to resolve"
    exit 1
  fi

  local QQ="Owner,Groups,Perms"

  local EA=$(get_EnvID "$1")
  if [[ $EA -le 0 ]]; then
    echo "Environment '$1' not found"
    exit 1
  fi

  local EB=$(get_EnvID "$2")
  if [[ $EB -le 0 ]]; then
    echo "Environment '$2' not found"
    exit 1
  fi

  # First, we need to set the process flag for all files to 0.
  query "UPDATE Files SET Process=0"


  # First we process all the entries for the first environment, and compare the second environment.
  local AxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EA AND Process=0 LIMIT 1;")
  while [[ -n "$AxFileID" ]]; do
    local HASH=$(query_ro "SELECT NameHash FROM Files WHERE FileID=$AxFileID";)
    local FileName=$(query_ro "SELECT FileName FROM Files WHERE FileID=$AxFileID";)

    # Now look for the other file from the second environment that has the same name.
    local BxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EB AND NameHash='$HASH';")
    if [[ $BxFileID -le 0 ]]; then
      echo "#$1: $FileName missing on $2"
      query "UPDATE Files SET Process=1 WHERE FileID=$AxFileID"
    else
   
      local AxP=$(query_ro "SELECT $QQ FROM Files WHERE FileID=$AxFileID LIMIT 1;")
      local BxP=$(query_ro "SELECT $QQ FROM Files WHERE FileID=$BxFileID LIMIT 1;")
      
      if [[ $AxP != $BxP ]]; then
        echo -e "\n## $FileName \t($AxP) ($BxP)"
        
        [[ $DEBUG ]] && echo "local FileX=$(printf '%q' \"$FileName\")"
        local FileX=$(printf '%q' "$FileName")
        [[ $DEBUG ]] && sleep 20

        local AxOwner=$(query_ro "SELECT Owner FROM Files WHERE FileID=$AxFileID LIMIT 1;")
        local AxGroup=$(query_ro "SELECT Groups FROM Files WHERE FileID=$AxFileID LIMIT 1;")
        local AxPerms=$(query_ro "SELECT Perms FROM Files WHERE FileID=$AxFileID LIMIT 1;")

        local BxOwner=$(query_ro "SELECT Owner FROM Files WHERE FileID=$BxFileID LIMIT 1;")
        local BxGroup=$(query_ro "SELECT Groups FROM Files WHERE FileID=$BxFileID LIMIT 1;")
        local BxPerms=$(query_ro "SELECT Perms FROM Files WHERE FileID=$BxFileID LIMIT 1;")

        if [[ "$AxOwner" != "$BxOwner" ]]; then
            if [[ "$AxGroup" != "$BxGroup" ]]; then
              echo "chown $AxOwner:$AxGroup $FileX"
            else
              echo "chown $AxOwner $FileX"
            fi
        else
          if [[ "$AxGroup" != "$BxGroup" ]]; then
            echo "chgrp $AxGroup $FileX"
          fi  
        fi

        if [[ "$AxPerms" != "$BxPerms" ]]; then
          # Convert the perms to a number.

          if [[ "$AxPerms" = 'drwxrwsrwx+' ]]; then
            echo "chmod 2777 $FileX"
          elif [[ "$AxPerms" = 'drwxrwsr-+' ]]; then
            echo "chmod 2774 $FileX"
          elif [[ "$AxPerms" = 'drwxrwsr-x.' ]]; then
            echo "chmod 2775 $FileX"
          else

            local newPerms=$(echo $AxPerms | sed 's/--x/1/g'|sed 's/-w-/2/g'|sed 's/-wx/3/g'|sed 's/r--/4/g'|sed 's/r-x/5/g'|sed 's/rw-/6/g'|sed 's/rwx/7/g' | sed 's/---/0/g'|sed 's/-//g'|sed 's/\.//g'|sed 's/^d//g')
            echo "chmod $newPerms $FileX"
          fi

          sleep 1
        fi
      fi

      query "UPDATE Files SET Process=1 WHERE FileID=$AxFileID OR FileID=$BxFileID"
    fi

    AxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EA AND Process=0 LIMIT 1;")
  done


  # Now list all the times in the second environment that was not in the first.
  local BxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EB AND Process=0 LIMIT 1;")
  while [[ -n "$BxFileID" ]]; do
    local FileName=$(query_ro "SELECT FileName FROM Files WHERE FileID=$BxFileID";)

    echo "# $2: $FileName missing on $1"
    query "UPDATE Files SET Process=1 WHERE FileID=$BxFileID"

    BxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$EB AND Process=0 LIMIT 1;")
  done
}


# Check against the specified environment and alert if there are files without md5sums.
# If no environment is mentioned, then it will check all environments.
function check_md5_exists() {
  if [[ -z "$1" ]]; then
    # Check all environments.
    local xFound=$(query_ro "SELECT FileID FROM Files WHERE Dir=0 AND Md5hash IS NULL LIMIT 1;")
  else
    # Check specific environment
    local zEnvID=$(get_EnvID "$1")
    if [[ -z $zEnvID ]]; then
      return 1;
    else
      local xFound=$(query_ro "SELECT FileID FROM Files WHERE Dir=0 AND EnvID=$zEnvID AND Md5hash IS NULL LIMIT 1;")
    fi
  fi

  if [[ -z $xFound ]]; then
    return 0;
  else
    echo "WARNING: Files in system do not have MD5 values, so wont be able to compare"
    return 1;
  fi
}

# After gathering all the information about files, with this, we want to get the MD5 sum of
# a file, and then list all the other environments/files that have the same content.
function find_file() {

  if [[ -z "$1" ]]; then
    echo "Parameters missing."
    return 1;
  fi

  declare -A env_list

  ### Check if files in the DB do not have MD5sum's and warn the user.
  check_md5_exists

  # go through the list of files presented.
  while [[ -n "$1" ]]; do
    if [[ -d "$1" ]]; then
      # This is a directory, so call it again

      for ENTRY in $1/*; do
        if [[ -e $ENTRY ]]; then
          find_file "$ENTRY"
        fi
      done

    elif [[ -r "$1" ]]; then

      # Get the MD5sum of the specified file.
      local xMD5hash=$(md5sum "$1"|awk '{print $1}')

      query "UPDATE Files SET Process=0"
      local xFound=0

      echo "$1:"

      # Search the Database for any files that have that same MD5sum
      local AxFileID=$(query_ro "SELECT FileID FROM Files WHERE Md5hash='$xMD5hash' AND Process=0 LIMIT 1;")
      while [[ -n "$AxFileID" ]]; do
        local FileName=$(query_ro "SELECT FileName FROM Files WHERE FileID=$AxFileID";)
        local EnvID=$(query_ro "SELECT EnvID FROM Files WHERE FileID=$AxFileID";)
        local EnvName=${env_list["$EnvID"]}
        if [[ -z $EnvName ]]; then
          # We dont have the env name cached, so looked it up and add to the hash-array.
          EnvName=$(query_ro "SELECT Name FROM Environments WHERE EnvID=$EnvID";)
          env_list["$EnvID"]=$EnvName
        fi

        query "UPDATE Files SET Process=1 WHERE FileID=$AxFileID"

        echo -e "\t$FileName \t($EnvName)"

        AxFileID=$(query_ro "SELECT FileID FROM Files WHERE Md5hash='$xMD5hash' AND Process=0 LIMIT 1;")
      done

    else
      echo "Unable to open: $1"
    fi

    shift
  done
}

# This will output scripting to remove files in the second environment that have the same content as files in the first environment.
function remove_dup() {

  if [[ -z "$1" ]]; then
    echo "Parameters missing."
    return 1;
  fi

  local zEA=$(get_EnvID "$1")
  local zEB=$(get_EnvID "$2")

  if [[ $zEA -eq 0 ]]; then
    echo "Missing environment: $1"
    return 1
  fi

  if [[ $zEB -eq 0 ]]; then
    echo "Missing environment: $2"
    return 1
  fi

  ### Check if files in the DB do not have MD5sum's and warn the user.
  check_md5_exists $1
  check_md5_exists $2

  # First, we need to set the process flag for all files to 0.
  query "UPDATE Files SET Process=0"

  # First we process all the entries for the second environment, and compare against the first environment.
  local BxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$zEB AND Dir=0 AND Process=0 LIMIT 1;")
  while [[ -n "$BxFileID" ]]; do
    local HASH=$(query_ro "SELECT Md5hash FROM Files WHERE FileID=$BxFileID;")
    local FileName=$(query_ro "SELECT FileName FROM Files WHERE FileID=$BxFileID;")

    [[ $DEBUG ]] && echo "Checking: $FileName"

    # Now look for another file from the second environment that has the same hash.
    local AxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$zEA AND Md5hash='$HASH' AND Process=0 LIMIT 1;")
    if [[ "$AxFileID" -le 0 ]]; then
      query "UPDATE Files SET Process=1 WHERE FileID=$BxFileID;"
    else
      local FileNameSrc=$(query_ro "SELECT FileName FROM Files WHERE FileID=$AxFileID;")
      local FileX=$(printf '%q' "$FileName")

      echo "# ($1): $FileNameSrc ($AxFileID)"
      echo "# ($2): $FileName ($BxFileID)" 
      echo "rm $FileX"
      echo

      query "UPDATE Files SET Process=1 WHERE FileID=$AxFileID OR FileID=$BxFileID;"
    fi

    BxFileID=$(query_ro "SELECT FileID FROM Files WHERE EnvID=$zEB AND Dir=0 AND Process=0 LIMIT 1;")
  done
}







#----------------------------------

if [[ -z "$1" ]]; then 
  usage
  exit 1
fi


if [[ ! -e $DB_FILE ]]; then 
  create_db
fi




case $1 in
  init)         echo "Initialised" ;;
  get|grab)     grab $2 $3  ;;
  md5|md5sum)   grab $2 $3 md5 ;;
  process)      process "$2" "$3" ;;
  process_md5)  process_md5 "$2" "$3" ;;
  compare)      compare "$2" "$3" "Owner,Groups,Perms" ;;
  owner)        compare "$2" "$3" "Owner,Groups"       ;;
  compare_md5)  compare "$2" "$3" "Md5hash" ;;
  fix)          fix "$2" "$3" ;;
  find)         find_file "${@:2}" ;;
  remove_dup)   remove_dup "$2" "$3" ;;
  missing)      compare  "$2" "$3" "Filename" ;;
  combine)      combine "$2" ;;
  *)            usage ;;

esac


# echo "Done!"

