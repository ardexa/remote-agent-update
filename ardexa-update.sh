#!/bin/bash
#
# Ardexa Upgrade script: upgrades a remote Ardexa agent
#
# (c) Ardexa Pty Ltd 2017.
#
# 1. If script not running as root; then exit
# 2. If script arg for location of new Ardexa agent file doesn't exist or is empty; then exit
# 3. If current agent binary does not exist; then exit (this sript will NOT install a new agent)
# 4. Capture version of current agent
# 5. Capture version of new agent
# 6. If can't copy new binary to /usr/sbin/ardexa.NEW; If it can't, exit
# 7. Backup copy /usr/sbin/ardexa to /usr/sbin/ardexa.BAK
# 8. Place a cron entry to stop service; copy across backup to /usr/sbin/ardexa; restart service on reboot
# 9. Stop the ardexa service, based on the init system in use.
# 10. Check that ardexa is not running. If it is, exit
# 11. Rename new agent to '/usr/sbin/ardexa'. If it can't do that, restart service, rm the cron file and exit with an error
# 12. Restart the service. If it doesn't start, cp /usr/sbin/ardexa.BAK to /usr/sbin/ardexa, restart the service and rm the cron file
# 13. Remove the cron recovery file
# NOTE: ardexa.NEW and ardexa.BAK are left in /usr/sbin

ARDEXA_BIN="ardexa"
ARDEXA_TEMP="ardexa.NEW"
ARDEXA_BACKUP="ardexa.BAK"
BINARY_DIR="/usr/sbin"
LOCATION_NEW=""
LOCATION_OLD=""
ERROR=0
DEBUG=0
# Ardexa init files
SYSV_INIT="/etc/init.d/ardexa"
UPSTART_INIT="/etc/init/ardexa.conf"
CRON_FILE="/etc/cron.d/ardexa_recovery"

## Functions ##

check_service() {
	# Check the Ardexa service
	PROCESS_NUM=$(ps -ef | grep $1 | grep -v $2 | grep -v 'grep' | wc -l)
	# If its not, return 0
	if [ $PROCESS_NUM -eq 0 ]; then
		return 0
	fi
	# if process is running, return 1
	if [ $PROCESS_NUM -eq 1 ]; then
		return 1
	fi
	# else, return 2
	return 2
}

usage() {
    echo "Usage: $0 --newfile <location of new file>"
}

start_stop_service() {
	# Start/Stop the ardexa service, just in case. Suppress the output.
	if [ -f $SYSV_INIT ]; then
		invoke-rc.d ardexa $1 >/dev/null 2>&1
	fi
	# ..or.. Restart the Upstart service if it exists, just in case. Suppress the output.
	if [ -f $UPSTART_INIT ]; then
		$1 ardexa >/dev/null 2>&1
	fi
	# Start/Stop the SystemD service if it exists, just in case. Suppress the output.
	if command -v systemctl > /dev/null ; then
		systemctl $1 ardexa.service >/dev/null 2>&1
	fi
}

## END Functions ##

# This allows the disown script to finish and send the PID to the cloud
sleep 5

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
	usage
   exit 1
fi

# Process options
while [ $# -gt 0 ]; do
    case "$1" in
        --newfile  ) LOCATION_NEW=$2
                     shift 2 ;;
        # unknown options
        --*        ) echo "$PROGNAME: unknown option: $1"
                     ERROR=1
                     shift ;;
        # errors
        *          ) shift ;;

    esac
done

# Check that the 'LOCATION_NEW' file exists
if [ ! -f $LOCATION_NEW ] || [ -z "$LOCATION_NEW" ] ; then
    echo "Error. --newfile argument must specify the location of the new Ardexa agent file"
    ERROR=1
fi

# Check that the 'LOCATION_OLD' file exists. This is not necessarily an error condition
if [ ! -f $LOCATION_OLD ]; then
    echo "Error. Old ardexa file must exist"
	ERROR=1
fi

if [ $ERROR -eq 1 ]; then
	echo "Exiting due to errors."
	usage
	exit 1
fi

LOCATION_OLD="$BINARY_DIR/$ARDEXA_BIN"
OLD_VERS=$("$LOCATION_OLD" -v)
NEW_VERS=$("$LOCATION_NEW" -v)

# Show parameters (debugging)
if [ $DEBUG -eq 1 ]; then
	echo "Location of old agent: " $LOCATION_OLD
	echo "Old Version: " $OLD_VERS
	echo "Location of new agent: " $LOCATION_NEW
	echo "New Version: " $NEW_VERS
	echo "ERROR setting: " $ERROR
fi

# Copy across the new file to /usr/sbin in a temporary file, and check if it can't do that
cp "$LOCATION_NEW" "$BINARY_DIR/$ARDEXA_TEMP"
if [ $? -ne 0 ]; then
	echo "Error copying from" $LOCATION_NEW " to " "$BINARY_DIR/$ARDEXA_TEMP"
	exit 1
fi

# Take a backup of the existing binary
cp "$LOCATION_OLD" "$BINARY_DIR/$ARDEXA_BACKUP"
if [ $? -ne 0 ]; then
	echo "Error copying from" $LOCATION_OLD " to " "$BINARY_DIR/$ARDEXA_BACKUP"
	exit 1
fi

# Create the cron file
cat > $CRON_FILE << 'END_CRON'
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
@reboot root service ardexa stop && cp /usr/sbin/ardexa.BAK /usr/sbin/ardexa && service ardexa start
END_CRON

start_stop_service "stop"

# Check that the service is NOT running. Should return 0 if its NOT running
check_service "$BINARY_DIR/$ARDEXA_BIN" "$LOCATION_NEW"
if [ $? -ne 0 ]; then
	echo "Ardexa process cannot be stopped. Exiting."
	rm $CRON_FILE
	exit 1
fi

# Copy across the new file to /usr/sbin/ardexa, and check if it can't do that
# If it can't, start the service and exit
cp "$LOCATION_NEW" "$BINARY_DIR/$ARDEXA_BIN"
if [ $? -ne 0 ]; then
	echo "Error copying from" $LOCATION_NEW " to " "$BINARY_DIR/$ARDEXA_BIN"
	start_stop_service "start"
	rm $CRON_FILE
	exit 1
fi

start_stop_service "start"

# Check that the service is running. Should return 1 if its running
# If it doesn't, restore the backup and restart the service
check_service "$BINARY_DIR/$ARDEXA_BIN" "$LOCATION_NEW"
if [ $? -ne 1 ]; then
	echo "Ardexa process cannot be started with the new binary. Restoring the original version."
	cp "$BINARY_DIR/$ARDEXA_BACKUP" "$BINARY_DIR/$ARDEXA_BIN"
	start_stop_service "start"
	rm $CRON_FILE
	exit 1
fi

rm $CRON_FILE
