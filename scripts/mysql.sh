#!/bin/bash
### MySQL Server Login Info ###
MUSER="root"
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
BAK="/home/backup_manager/pre_backup_files/mysql"
GZIP="$(which gzip)"
NOW=$(date +"%d-%m-%Y")
DBS="$($MYSQL -u $MUSER -h $MHOST -Bse 'show databases')"
for db in $DBS
do
 if [ $db != "information_schema" ] && [ $db != "performance_schema" ] && [ $db != "test" ] && [ $db != "mysql" ]; then
   if [ ! -d $BAK/$db ]; then
     mkdir -p $BAK/$db
   fi
   FILE=$BAK/$db/$NOW-$(date +"%T").gz
   $MYSQLDUMP -u $MUSER -h $MHOST --skip-lock-tables --events $db | $GZIP -9 > $FILE
 fi
done

### CLEAN OLD MYSQL BACKUPS ###
###   2 day backup saving   ###
find $BAK -type f -mtime +1 -exec rm -v {} \;
