#!/bin/bash

DBUSER=zzz
DBPASSWORD=zzz
DBSOURCENAME=zzz
DUMPNAME=zzz
DBNAME=zzz

echo "Copying database..."
DBCONN="-u ${DBUSER} --password=${DBPASSWORD}"
echo "DROP DATABASE IF EXISTS ${DBNAME}" | mysql ${DBCONN}
echo "CREATE DATABASE ${DBNAME}" | mysql ${DBCONN}
echo "Dumping original database... "
mysqldump --opt ${DBCONN} ${DBSOURCENAME} > ${DUMPNAME}
echo "Importing to new name... "
mysql ${DBCONN} ${DBNAME} < ${DUMPNAME}

# individual table queries start here
echo "Renaming tables..."
echo "RENAME TABLE Occurrence TO occurrences" | mysql ${DBCONN} ${DBNAME}
echo "RENAME TABLE record_review TO reviews" | mysql ${DBCONN} ${DBNAME}
echo "RENAME TABLE User TO users" | mysql ${DBCONN} ${DBNAME}
echo "RENAME TABLE asc_model TO asc_models" | mysql ${DBCONN} ${DBNAME}

echo "Renaming occurrences columns..."
echo "ALTER TABLE occurrences CHANGE Validated validated TINYINT(1);" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE occurrences CHANGE AcceptedSpecies acceptedspecies TEXT;" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE occurrences CHANGE ID id INT(11);" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE occurrences CHANGE DecimalLatitude decimallatitude DOUBLE(10,7);" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE occurrences CHANGE DecimalLongitude decimallongitude DOUBLE(10,7);" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE occurrences CHANGE YearCollected yearcollected INT(11);" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE occurrences CHANGE Class class_name TEXT;" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE occurrences CHANGE Public public_record TINYINT(1);" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE occurrences CHANGE EmailVisible email_visible TINYINT(1);" | mysql ${DBCONN} ${DBNAME}

echo "Renaming remaining columns..."
echo "ALTER TABLE users CHANGE session_id sessionid VARCHAR (256); " | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE users CHANGE open_id openid VARCHAR(32);" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE reviews CHANGE occurrenceId occurrence_id INT(10) unsigned;" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE reviews CHANGE userID user_id INT(10) unsigned;" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE reviews CHANGE reviewed review TINYINT(1);" | mysql ${DBCONN} ${DBNAME}
echo "ALTER TABLE asc_models CHANGE id id INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY(id);" | mysql ${DBCONN} ${DBNAME}

# optional, if you plan to add occurrences through AR:
# "ALTER TABLE occurrences MODIFY id INT(11) NOT NULL AUTO_INCREMENT;" | mysql ${DBCONN} ${DBNAME}

echo "Done"
