#!/bin/bash
# Author: Clinton Webb
# (c) copyright, Clinton Webb, 2024.


DB_FILE=${DB_FILE:-arki.db}
#DEBUG=1
#DEBUG=2

FMT_NORMAL=$(tput sgr0)
FMT_GREEN=$(tput setaf 2; tput bold)
FMT_YELLOW=$(tput setaf 3)
FMT_RED=$(tput setaf 1; tput bold)



function usage() {
  echo "usage..."
  exit 1
}

function warn()  { echo -e "$FMT_YELLOW$*$FMT_NORMAL"; }
function error() { echo -e "$FMT_RED$*$FMT_NORMAL"; }



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
    sqlite3 -init <(echo ".timeout 20000") -csv $DB_FILE "$1" 2>/dev/null|tail -n +2
  }
  function query_ro() {
    [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2
    sqlite3 -readonly -init <(echo ".timeout 20000") -csv $DB_FILE "$1" 2>/dev/null|tail -n +2
  }
else
  function query() {
    [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2
    sqlite3 -init <(echo ".timeout 20000") -csv $DB_FILE "$1" 2>/dev/null
  }

  function query_ro() {
    [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2
    sqlite3 -readonly -init <(echo ".timeout 20000") -csv $DB_FILE "$1" 2>/dev/null
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
 Path STRING,
 Filename STRING NOT NULL,
 Size  INTEGER,
 Md5hash STRING,
 Linked INTEGER DEFAULT 0,
 Process INTEGER
);

CREATE TABLE Doubles (
 ItemID INTEGER UNIQUE PRIMARY KEY,
 SourceID INTEGER NOT NULL,
 Path STRING,
 Filename STRING,
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
  TARG=${2:-.}

  if [[ -z "$CENV" ]]; then
    error "Failed.  Environment required"
    exit 1
  fi

  if [[ ! -d "$TARG" ]]; then
    error "Target directory doesn't exist."
    exit 1
  fi

  local EnvID=$(get_EnvID $CENV)
  if [[ $EnvID -le 0 ]]; then
    warn "Environment '$CENV' doesn't exist.  Creating."
    EnvID=$(query_insert "INSERT INTO Environments (Name) VALUES ('$CENV');")
  fi

  find -L $TARG -type f -exec $0 process $EnvID '{}' \;
}

function process() {
  local xEnvID=$1
  local FILE="$2"
  echo "Processing '$FILE'"

  #get the filename (exclude the directory)
  local xFDIR=${FILE%/*}
  local xFNAME=${FILE##*/}
  local xSHORT=${xFNAME%.*}
#  local xNameHash=$(echo "$xFNAME"|md5sum|awk '{print $1}')
  local xNameHash=$(echo "$xSHORT"|md5sum|awk '{print $1}')

  if [[ -d "$FILE" ]]; then
    error "ERROR.  Directory $FILE"
    exit 2
  fi

  local xFileID=$(query_ro "SELECT FileID FROM Files WHERE NameHash='${xNameHash}';")

  if [[ -n $xFileID ]]; then
    local OPA=$(query_ro "SELECT Path,Filename FROM Files WHERE FileID=$xFileID;")
    warn "File already exists: ${xFDIR}/${xFNAME} ($OPA)"
    query "INSERT INTO Doubles (SourceID, Path, Filename, Process) VALUES ($xFileID, '$xFDIR', '${xFNAME//\'/\'\'}', 0);"
    exit 1
  else
     local OUTP=($(ls -ld "$FILE"))
    local xSize=${OUTP[4]}

    [[ $DEBUG -gt 0 ]] && echo "INSERT INTO Files (NameHash, EnvID, Path, Filename, Size, Process) VALUES ('$xNameHash', $xEnvID, '$xFDIR', '${xFNAME//\'/\'\'}', $xSize, 0);"
    xFileID=$(query_insert "INSERT INTO Files (NameHash, EnvID, Path, Filename, Size, Process) VALUES ('$xNameHash', $xEnvID, '$xFDIR', '${xFNAME//\'/\'\'}', $xSize, 0);")
    [[ $? -ne 0 ]] && (echo "Failed to INSERT!"; sleep 5)
    [[ $DEBUG -gt 0 ]] && echo "FileID: $xFileID"
    exit 0
  fi
}



function create() {
  CENV=$1
  TARG=${2:-.}

  if [[ -z "$CENV" ]]; then
    error "Failed.  Environment required"
    exit 1
  fi

  if [[ ! -d "$TARG" ]]; then
    error "Target directory doesn't exist."
    exit 1
  fi

  local EnvID=$(get_EnvID $CENV)
  if [[ $EnvID -le 0 ]]; then
    error "Environment '$CENV' doesn't exist. Cannot Process."
    exit 1
  else
    [[ -d watch ]] || mkdir watch
    [[ -d watch/_unmatched ]] || mkdir watch/_unmatched

    query "UPDATE Files SET Process=0;"

    find -L $TARG -type f -exec $0 create_process $EnvID '{}' \;
  fi
}

function create_process() {
  local xEnvID=$1
  local FILE="$2"
  echo "Processing '$FILE'"

  #get the filename (exclude the directory)
  local xFDIR=${FILE%/*}
  local xFNAME=${FILE##*/}
  local xSHORT=${xFNAME%.*}
#  local xNameHash=$(echo "$xFNAME"|md5sum|awk '{print $1}')
  local xNameHash=$(echo "$xSHORT"|md5sum|awk '{print $1}')

  local OUTP=($(ls -ld "$FILE"))
  local xSize=${OUTP[4]}

  IFS=',';
  local xFileInfo=($(query_ro "SELECT FileID,Size,Linked,Process,Path FROM Files WHERE NameHash='${xNameHash}'"))
  unset IFS

  [[ $DEBUG -gt 0 ]] && declare -p xFDIR xFNAME xNameHash OUTP xFileInfo

  if [[ -n "$xFileInfo" ]]; then
    local xFileID=${xFileInfo[0]}
    local xFileSize=${xFileInfo[1]}
    local xFileLinked=${xFileInfo[2]}
    local xFileProcess=${xFileInfo[3]}
    local xFilePath=${xFileInfo[4]}

    [[ $DEBUG -gt 0 ]] && declare -p xFileInfo xFileID xFileSize xFileLinked xFileProcess xFilePath

    if [[ $xFileLinked -gt 0 ]]; then
      warn "File already linked: $FILE"
      sleep 5
    elif [[ $xFileProcess -gt 0 ]]; then
      warn "File already processed: $FILE"
      sleep 5
    elif [[ -z $xFilePath ]]; then
      error "Expecting path: '$xFilePath'"
      sleep 5
    else
      [[ -d watch/$xFilePath ]] || mkdir watch/$xFilePath
      cp -v -l "$FILE" watch/$xFilePath/

      query "UPDATE Files SET Linked=1, Process=1 WHERE FileID=$xFileID;"
    fi
  else
    # File not there,
    echo "Unmatched: $xFNAME"
    cp -l "$FILE" watch/_unmatched/
  fi
}

# The purpose is to remove files that have been linked.
function cleanup() {
  CENV=$1
  TARG=${2:-.}

  if [[ -z "$CENV" ]]; then
    error "Failed.  Environment required"
    exit 1
  fi

  if [[ ! -d "$TARG" ]]; then
    error "Target directory doesn't exist."
    exit 1
  fi

  local EnvID=$(get_EnvID $CENV)
  if [[ $EnvID -le 0 ]]; then
    error "Environment '$CENV' doesn't exist. Cannot Process."
    exit 1
  else
    query "UPDATE Files SET Process=0;"

    IFS=',';
    local xFileInfo=($(query_ro "SELECT FileID,Path,Filename FROM Files WHERE EnvID=$EnvID AND Linked=1 AND Process=0 LIMIT 1;"))
    unset IFS

    while [[ -n "$xFileInfo" ]]; do
      local xFileID=${xFileInfo[0]}
      local xFilePath=${xFileInfo[1]}
      local xFileName=${xFileInfo[2]}

      xFileName="${xFileName%\"}"
      xFileName="${xFileName#\"}"

#      [[ $DEBUG -gt 0 ]] && declare -p xFileInfo xFileID xFilePath xFileName
      [[ $DEBUG -gt 0 ]] && echo "$xFilePath/$xFileName"

      if [[ -e "$xFilePath/$xFileName" ]]; then
        echo "Deleting: $xFilePath/$xFileName"
        rm "$xFilePath/$xFileName"
      fi

      query "UPDATE Files SET Process=1 WHERE FileID=$xFileID;"

      IFS=',';
      local xFileInfo=($(query_ro "SELECT FileID,Path,Filename FROM Files WHERE EnvID=$EnvID AND Linked=1 AND Process=0 LIMIT 1;"))
      unset IFS
    done
  fi
}


#-------------------------------------------------------------------------------
[[ ! -e $DB_FILE ]] && create_db

case $1 in
  init)           echo "Initialised" ;;
  get|add)        grab $2 $3  ;;
  process)        process "$2" "$3" ;;

  create)         create "$2" "$3" ;;
  create_process) create_process "$2" "$3" ;;

  clean)          cleanup "$2" ;;

#  compare)      compare "$2" "$3" "Owner,Groups,Perms" ;;
#  owner)        compare "$2" "$3" "Owner,Groups"       ;;
#  compare_md5)  compare "$2" "$3" "Md5hash" ;;
#  fix)          fix "$2" "$3" ;;
#  find)         find_file "${@:2}" ;;
#  remove_dup)   remove_dup "$2" "$3" ;;
#  missing)      compare  "$2" "$3" "Filename" ;;
#  combine)      combine "$2" ;;
  *)            usage ;;

esac

