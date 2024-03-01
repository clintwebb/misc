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

function usage() {
  echo "parameters required"
  exit 1
}


# This query function will allow us to perform an operation
function query() {
  if [[ -e .init.sql ]]; then
    sqlite3 -init .init.sql $DB_FILE "$1" 2>/dev/null|tail -n +2
  else
    sqlite3 $DB_FILE "$1" 2>/dev/null
  fi
}

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
INSERT INTO Settings (Name, Value) VALUES ("Version", "1");

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
  local NAME=$1
  local VALUE=$(query "SELECT Value FROM Settings WHERE Name='$NAME';");
  echo "$VALUE"
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

  local EnvID=$(query "SELECT EnvID FROM Environments WHERE Name='$CENV';");
  if [[ $EnvID -le 0 ]]; then
    echo "Environment '$CENV' doesn't exist.  Creating."
    EnvID=$(query_insert "INSERT INTO Environments (Name) VALUES ('$CENV');")
  fi

  if [[ $MD5 == 'md5' ]]; then
    find -L $TARG -exec ./grabber.sh process_md5 $EnvID '{}' \;
  else
    find -L $TARG -exec ./grabber.sh process $EnvID '{}' \;
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

#  echo "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0);"
  xFileID=$(query_insert "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0);")
#  echo "FileID: $xFileID"
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
    #  echo "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0);"
    xFileID=$(query_insert "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0);")
    #  echo "FileID: $xFileID"
  else
    local xMD5hash=$(md5sum $FILE|awk '{print $1}')
    xFileID=$(query_insert "INSERT INTO Files (NameHash, EnvID, Dir, Perms, Owner, Groups, Size, Filename, Process, Md5hash) VALUES ('$xNameHash', $xEnvID, $xDir, '$xPerms', '$xOwner', '$xGroups', $xSize, '$FILE', 0, '$xMD5hash');")
    #  echo "FileID: $xFileID"
  fi
}

function ginfo() {
  local Item=$1
  local FileID=$2

  >&2 echo "SELECT $Item FROM Files WHERE FileID=$FileID LIMIT 1;"
  query "SELECT $Item FROM Files WHERE FileID=$FileID LIMIT 1;"
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

  local EA=$(query "SELECT EnvID FROM Environments WHERE Name='$1';")
  if [[ $EA -le 0 ]]; then
    echo "Environment '$1' not found"
    exit 1
  fi

  local EB=$(query "SELECT EnvID FROM Environments WHERE Name='$2';")
  if [[ $EB -le 0 ]]; then
    echo "Environment '$2' not found"
    exit 1
  fi

  # First, we need to set the process flag for all files to 0.
  query "UPDATE Files SET Process=0"


  # First we process all the entries for the first environment, and compare the second environment.
  local AxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EA AND Process=0 LIMIT 1;")
  while [[ -n "$AxFileID" ]]; do
    local HASH=$(query "SELECT NameHash FROM Files WHERE FileID=$AxFileID";)
    local FileName=$(query "SELECT FileName FROM Files WHERE FileID=$AxFileID";)

    # Now look for the other file from the second environment that has the same name.
#    echo "SELECT FileID FROM Files WHERE EnvID=$EB AND NameHash='$HASH';"
    local BxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EB AND NameHash='$HASH';")
    if [[ $BxFileID -le 0 ]]; then
      echo "$1: $FileName missing on $2"
      query "UPDATE Files SET Process=1 WHERE FileID=$AxFileID"
    else

      local AxP=$(query "SELECT $QQ FROM Files WHERE FileID=$AxFileID LIMIT 1;")
      local BxP=$(query "SELECT $QQ FROM Files WHERE FileID=$BxFileID LIMIT 1;")

      if [[ $AxP != $BxP ]]; then
        echo -e "$FileName \t($AxP) ($BxP)"
      fi

      query "UPDATE Files SET Process=1 WHERE FileID=$AxFileID OR FileID=$BxFileID"

    fi

    AxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EA AND Process=0 LIMIT 1;")
  done


  # Now list all the times in the second environment that was not in the first.
  local BxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EB AND Process=0 LIMIT 1;")
  while [[ -n "$BxFileID" ]]; do
    local FileName=$(query "SELECT FileName FROM Files WHERE FileID=$BxFileID";)

    echo "$2: $FileName missing on $1"
    query "UPDATE Files SET Process=1 WHERE FileID=$BxFileID"

    BxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EB AND Process=0 LIMIT 1;")
  done
}


## Fix will generate output that can essentially be scripted to fix things between the environments.
# The first argument is the source, the second is the destination (what should be fixed to match the source)
function fix() {
  if [[ -z "$2" ]]; then
    echo "ERROR.  Expect two environments to resolve"
    exit 1
  fi

  local QQ="Owner,Groups,Perms"

  local EA=$(query "SELECT EnvID FROM Environments WHERE Name='$1';")
  if [[ $EA -le 0 ]]; then
    echo "Environment '$1' not found"
    exit 1
  fi

  local EB=$(query "SELECT EnvID FROM Environments WHERE Name='$2';")
  if [[ $EB -le 0 ]]; then
    echo "Environment '$2' not found"
    exit 1
  fi

  # First, we need to set the process flag for all files to 0.
  query "UPDATE Files SET Process=0"


  # First we process all the entries for the first environment, and compare the second environment.
  local AxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EA AND Process=0 LIMIT 1;")
  while [[ -n "$AxFileID" ]]; do
    local HASH=$(query "SELECT NameHash FROM Files WHERE FileID=$AxFileID";)
    local FileName=$(query "SELECT FileName FROM Files WHERE FileID=$AxFileID";)

    # Now look for the other file from the second environment that has the same name.
    local BxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EB AND NameHash='$HASH';")
    if [[ $BxFileID -le 0 ]]; then
      echo "#$1: $FileName missing on $2"
      query "UPDATE Files SET Process=1 WHERE FileID=$AxFileID"
    else
   
      local AxP=$(query "SELECT $QQ FROM Files WHERE FileID=$AxFileID LIMIT 1;")
      local BxP=$(query "SELECT $QQ FROM Files WHERE FileID=$BxFileID LIMIT 1;")
      
      if [[ $AxP != $BxP ]]; then
        echo -e "\n## $FileName \t($AxP) ($BxP)"
        
#        echo "local FileX=$(printf '%q' \"$FileName\")"
        local FileX=$(printf '%q' "$FileName")
#sleep 20

        local AxOwner=$(query "SELECT Owner FROM Files WHERE FileID=$AxFileID LIMIT 1;")
        local AxGroup=$(query "SELECT Groups FROM Files WHERE FileID=$AxFileID LIMIT 1;")
        local AxPerms=$(query "SELECT Perms FROM Files WHERE FileID=$AxFileID LIMIT 1;")

        local BxOwner=$(query "SELECT Owner FROM Files WHERE FileID=$BxFileID LIMIT 1;")
        local BxGroup=$(query "SELECT Groups FROM Files WHERE FileID=$BxFileID LIMIT 1;")
        local BxPerms=$(query "SELECT Perms FROM Files WHERE FileID=$BxFileID LIMIT 1;")

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

    AxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EA AND Process=0 LIMIT 1;")
  done


  # Now list all the times in the second environment that was not in the first.
  local BxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EB AND Process=0 LIMIT 1;")
  while [[ -n "$BxFileID" ]]; do
    local FileName=$(query "SELECT FileName FROM Files WHERE FileID=$BxFileID";)

    echo "# $2: $FileName missing on $1"
    query "UPDATE Files SET Process=1 WHERE FileID=$BxFileID"

    BxFileID=$(query "SELECT FileID FROM Files WHERE EnvID=$EB AND Process=0 LIMIT 1;")
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
  *)            usage ;;

esac


# echo "Done!"

