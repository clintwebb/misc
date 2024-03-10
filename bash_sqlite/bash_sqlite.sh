# This is a simple method for bash scripts to store and access data.

# Query Example
#  VALUE=$(query "SELECT Value FROM Settings WHERE Name='$NAME';");
#
# Insert Example (which can return the PrimaryKey value from the INSERT).
#  EnvID=$(query_insert "INSERT INTO Environments (Name) VALUES ('$CENV');")

# Pre-setting DB_FILE to something else is recommended, but if none is specified, it will choose a default filename.
DB_FILE=${DB_FILE:-sqlite.db}

# This query function will allow us to perform an operation, but wait for 20 seconds if the file is locked.
# without a setting like this, if there is another operation on the file occuring at the same time, it will fail. 
function query() {
  [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2
  sqlite3 -init <(echo ".timeout 20000") $DB_FILE "$1" 2>/dev/null
}

function query_ro() {
  [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2
  sqlite3 -readonly -init <(echo ".timeout 20000") $DB_FILE "$1" 2>/dev/null
}



# This query function will allow us to perform an operation.  
# This was modified from the previous version, because it wasn't working quite right on an example legacy redhat7 server (it kept on outputting an extra blank line)
# Investigated.  Seems to be an issue with older versions (like in Redhat 7 or older) which causes an extra line to be output, which needs to be trimmed.
function query2() {
  [[ $SQL_DEBUG -gt 1 ]] && echo "$1" >&2

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

