#!/bin/bash

while getopts "d:l:" option
do
    case $option in
        d) DB_DUMP_FILE=$OPTARG;;
        l) LOG_DUMP_FILE=$OPTARG;;
    esac
done

if [ ! "$DB_DUMP_FILE" ] && [ ! "$LOG_DUMP_FILE" ];then
    echo "Usage: $0 -d DATABASE_BACKUP.gz -l LOG_BACKUP.tar.gz"
fi

if [ ! -z "$DB_DUMP_FILE" ];then
    echo "-->Restoring Mongo database from $DB_DUMP_FILE"
    ## Get db container
    ID=$(docker ps | grep mongo | cut -d" " -f1)
    if [ -z "$ID" ];then
      echo "--Container for service kernelci_mongo not found exiting--"
      exit 1
    fi

    echo $DB_DUMP_FILE |grep -q 'gz$'
    if [ $? -eq 0 ];then
	    gunzip $DB_DUMP_FILE || exit 1
	    DB_DUMP_FILE=$(echo $DB_DUMP_FILE | sed 's,.gz$,,')
    fi
    ## Copy dump to container
    docker cp $DB_DUMP_FILE $ID:/tmp || exit 1

    ## Restore dump
    echo "Restore $DB_DUMP_FILE"
    docker exec $ID /bin/bash -c "mongorestore --archive=/tmp/$DB_DUMP_FILE"
    if [ $? -ne 0 ];then
	    exit 1
    fi
fi

if [ ! -z "$LOG_DUMP_FILE" ];then
    echo "-->Restoring logs database from $LOG_DUMP_FILE"
    ## Restore logs
    tar xvf $LOG_DUMP_FILE || exit 1
    docker run --rm -v `pwd`/kernel-ci/:/tmp/kernelci_logs/ -v kernelci_kci:/var/lib/docker/volumes/kernelci_kci/_data busybox cp -r /tmp/kernelci_logs/. /var/lib/docker/volumes/kernelci_kci/_data
    rm -r kernel-ci/
fi

exit 0