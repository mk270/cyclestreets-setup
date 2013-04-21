#!/bin/bash
#	Used to restore viola from backups generated by olivia - when olivia is acting as the live machine
#	Uses output from the toViola script
#	And should be run manually on viola, as cyclestreets

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
echo "#	CycleStreets fromOlivia in progress, follow log file with: tail -f ${setupLogFile}"
echo "$(date)	CycleStreets fromOlivia $(id)" >> ${setupLogFile}


#	Download and restore the CycleStreets database.
#	This section is simlar to failover-deployment/daily-update.sh
#	Folder locations
server=olivia.cyclestreets.net
dumpPrefix=olivia

# Restore recent data
. ${SCRIPTDIRECTORY}/../utility/restore-recent.sh

# Finish
echo "$(date)	All done" >> ${setupLogFile}

# End of file
