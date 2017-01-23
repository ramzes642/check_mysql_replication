#!/bin/bash

#TODO
# tmp files not cleaned up automatically

# Nagios alert status
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
REPL_DIFFERENCE=1

usage="
Description: Checks master and slave log positions as well as slave status.

Usage: $0 -H <slave_host>

Script assumes:
 * it is run from the master server
 * ~/.my.cnf is configured with account which has privileges to SHOW MASTER STATUS and SHOW SLAVE STATUS.
 * English locale

More info at http://blog.endpoint.com/2012/01/mysql-replication-monitoring-on-ubuntu.html

Modified To retun Critical in case of Slave :
    - Last Errno not 0
    - IO Running: no
    - SQL running: no

The argument for slave in the difference operation has been change from "Read_Master_Log_Pos" to "Exec_Master_Log_Pos"

"

if [ -z $1 ]
then
    echo "$usage"
    exit $STATE_UNKNOWN
fi

while :; do
    case "$1" in
        '')
            echo $usage
            exit $STATE_UNKNOWN
            ;;
        -h)
            echo $usage
            exit $STATE_UNKNOWN
            ;;
        -H)
            SLAVEHOST=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo $usage
            exit $STATE_UNKNOWN
            ;;
    esac
    shift

    test -n "$1" || break
done

slave_status_file=`mktemp`
slave_error_file=`mktemp`
slave_connection_check=`mysql -h $SLAVEHOST -e "show slave status" >$slave_status_file 2>$slave_error_file`
if [[ $? -ne 0 ]]
then
    echo "Error reading slave: $(cat $slave_error_file)"
    rm -f $slave_error_file
    exit $STATE_CRITICAL
fi

#Replace Read_Master_Log_Pos By  Exec_Master_Log_Pos for comparaison purpose
#iSlave_1_position=`grep bin $slave_status_file | cut -f7`
iSlave_1_position=`grep bin $slave_status_file | cut -f22`
iSlave_1_status=`grep bin $slave_status_file | cut -f1`
iSlave_1_Slave_IO_Running=`grep bin $slave_status_file | cut -f11`
iSlave_1_Slave_SQL_Running=`grep bin $slave_status_file | cut -f12`
iSlave_1_Last_Errno=`grep bin $slave_status_file | cut -f19`
iSlave_1_Seconds_Behind_Master=`grep bin $slave_status_file | cut -f33`
rm -f $slave_status_file





if [[ "$iSlave_1_Slave_IO_Running" != "Yes" || "$iSlave_1_Slave_SQL_Running" != "Yes" || "$iSlave_1_Last_Errno" != "0" ]]
then
echo "CRITICAL - slave '$SLAVEHOST' IO/SQL RUNNING / Last_Errno: is not at 0 : IO RUNNING->'$iSlave_1_Slave_IO_Running' / SQL RUNNING->'$iSlave_1_Slave_SQL_Running' / Last_Errno->'$iSlave_1_Last_Errno'"
    rm_ifexist
    exit $STATE_CRITICAL
#END NEW CHECK
fi

if [ $iSlave_1_Seconds_Behind_Master -gt 60 ]
then
    echo "WARNING - slave $iSlave_1_Seconds_Behind_Master seconds behind master"
    exit $STATE_WARNING
else
    echo "OK - Seconds behind ($iSlave_1_Seconds_Behind_Master), slave status = '$iSlave_1_status'"
    exit $STATE_OK
fi

if [ "$iSlave_1_status" != "Waiting for master to send event" ]
then
    echo "CRITICAL - slave status is '$iSlave_1_status'"
    exit $STATE_CRITICAL
#NEW CHECK
fi

exit $STATE_CRITICAL
