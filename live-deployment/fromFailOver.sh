#!/bin/bash
#	Used to restore live machine from backups generated by failover - when failover is acting as the live machine
#	Uses output from the toLive script
#	And should be run manually on the live machine, as cyclestreets

### Stage 1 - general setup

# Ensure this script is NOT run as root (it should be run as cyclestreets)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi


# Bomb out if something goes wrong
set -e

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed because this script is likely symlinked from cron
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do 
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTDIRECTORY=$DIR

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Define the location of the credentials file relative to script directory
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x $SCRIPTDIRECTORY/${configFile} ]; then
    echo "# The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Logging
setupLogFile=$SCRIPTDIRECTORY/log.txt
touch ${setupLogFile}
echo "#	CycleStreets fromFailOver in progress, follow log file with: tail -f ${setupLogFile}"
echo "$(date)	CycleStreets fromFailOver $(id)" >> ${setupLogFile}


#	Download and restore the CycleStreets database.
#	This section is simlar to failover-deployment/daily-update.sh
#	Folder locations
server=${failoverServer}
dumpPrefix=failover

# Restore recent data
. ${SCRIPTDIRECTORY}/../utility/restore-recent.sh

# Restart the pseudoCron at today's date
mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "update map_config set pseudoCron = curdate();";

# Restore these cronjobs - note the timings of these should be the same as in the run.sh
cat <(crontab -l) <(echo "4 1 * * * ${ScriptHome}/live-deployment/daily-dump.sh") | crontab -
cat <(crontab -l) <(echo "34 1 * * * ${ScriptHome}/live-deployment/install-routing-data.sh") | crontab -

# Finish
echo "$(date)	All done" >> ${setupLogFile}

# End of file
