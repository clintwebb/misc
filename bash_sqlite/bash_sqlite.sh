# This is a simple method for bash scripts to store and access data.

# Query Example
#  VALUE=$(query "SELECT Value FROM Settings WHERE Name='$NAME';");
#
# Insert Example (which can return the PrimaryKey value from the INSERT).
#  EnvID=$(query_insert "INSERT INTO Environments (Name) VALUES ('$CENV');")

# Pre-setting DB_FILE to something else is recommended, but if none is specified, it will choose a default filename.
DB_FILE=${DB_FILE:-sqlite.db}


# This query function will allow us to perform an operation.  
function query() {

  [[ $DEBUG -gt 1 ]] && echo "$1" >&2

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

