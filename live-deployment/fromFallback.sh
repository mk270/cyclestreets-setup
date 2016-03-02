#!/bin/bash
#	Used to restore live machine from backups generated by fallback - when fallback is acting as the live machine
#	Uses output from the toLive script
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).

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


## Main body of script

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)."
    exit 1
fi

# Check a fallback server is setup
if [ -z "${fallbackServer}" ]; then
    echo "#	No fallback server is setup in the config."
    exit 1
fi



# Logging
echo "#	$(date)	CycleStreets fromFallback $(id)"


#	Download and restore the CycleStreets database.
#	This section is simlar to fallback-deployment/daily-update.sh
#	Folder locations
server=${fallbackServer}
dumpPrefix=fallback

# Restore recent data
. ${SCRIPTDIRECTORY}/../utility/restore-recent.sh

# Restart the pseudoCron at today's date
${superMysql} cyclestreets -e "update map_config set pseudoCron = curdate();";

# Restore these cronjobs - note the timings of these should be the same as in the run.sh
echo "#	$(date)	It is recommended to manually uncomment relevant cron jobs"
#cat <(crontab -l) <(echo "4 1 * * * ${SCRIPTDIRECTORY}/../live-deployment/daily-dump.sh") | crontab -
#cat <(crontab -l) <(echo "34 11 * * * ${SCRIPTDIRECTORY}/../live-deployment/install-routing-data.sh") | crontab -

# Finish
echo "#	$(date)	All done"

# End of file
