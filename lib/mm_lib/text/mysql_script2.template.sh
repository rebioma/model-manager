#!/bin/bash

DBUSER=zzz
DBPASSWORD=zzz
DBTABLENAME=zzz
DBFINALTABLE=zzz

echo "Dropping existing asc_model table: ${DBFINALTABLE}..."
DBCONN="-u ${DBUSER} --password=${DBPASSWORD}"
echo "DROP TABLE IF EXISTS ${DBFINALTABLE}" | mysql ${DBCONN}

echo "Copying new asc_model table to production database..."
echo "CREATE TABLE ${DBFINALTABLE} SELECT * FROM ${DBTABLENAME}" | mysql ${DBCONN}

echo "Done"
