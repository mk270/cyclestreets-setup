#!/bin/bash
# 
# SYNOPSIS
#	installLocalLatestEdition.sh
#
# DESCRIPTION
#	Used on a server that provides both the live and import deployments. Ie. usually a developer machine.
#	This script moves the files generated by the latest import run to the website data area so they can be used for routing.
#	Afterwards use ./switchRoutingEdition.sh to use the new edition.
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).

echo "#	$(date)	Install latest locally generated CycleStreets import routing edition"

# Ensure this script is NOT run as root
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must not be be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	An import is already running' ; exit 1; }

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file."
    exit 1
fi

# Load the credentials
. ${configFile}


## Main body of script

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)."
    exit 1
fi

# Check the import folder is defined
if [ -z "${importContentFolder}" ]; then
    echo "#	The import folder is not defined."
    exit 1
fi

# Check that the import finished correctly
if ! ${superMysql} --batch --skip-column-names -e "call importStatus()" cyclestreets | grep "valid\|cellOptimised" > /dev/null 2>&1
then
    echo "#	The import process did not complete. The routing service will not be started."
    exit 1
fi


### Determine latest import

# New routing editions should be found at this location
importMachineEditions=${importContentFolder}/output

# Read the folder of routing editions, one per line, newest first, getting first one
latestEdition=`ls -1t ${importMachineEditions} | head -n1`

# Abandon if not found
if [ -z "${latestEdition}" ]; then
    echo "Error: No editions found in ${importMachineEditions}"
    exit 1
fi

# Check (at least one of) the files exist
if [ ! -e ${importMachineEditions}/${latestEdition}/legDetail.tsv ]; then
    # This usually happens if trying re reinstall.
    echo "Error: TSV files missing in: ${importMachineEditions}/${latestEdition}"
    exit 1
fi


# Check this edition is not already installed
if [ -d ${websitesContentFolder}/data/routing/${latestEdition} ]; then
    echo "#	Edition ${latestEdition} is already installed - to remove it use:"
    echo "#	rm -r ${websitesContentFolder}/data/routing/${latestEdition}"
    exit 1
fi

#	Report finding
echo "#	Installing latest edition: ${latestEdition}"

# Move the folder
mv ${importMachineEditions}/${latestEdition} ${websitesContentFolder}/data/routing

# Create a symlink to the installed edition - this allows remote machines to install this edition
ln -s ${websitesContentFolder}/data/routing/${latestEdition} ${importMachineEditions}/${latestEdition}

# Create a file that indicates the end of the script was reached - this can be tested for by the switching script
touch "${websitesContentFolder}/data/routing/${latestEdition}/installationCompleted.txt"

# Report completion and next steps
echo "#	$(date) Installation completed."
echo "#	If the import was configured for supporting large amounts of data then a MySQL restart could restore values more appropriate for serving routes."
echo "#	To switch routing service use: ${ScriptHome}/live-deployment/switch-routing-edition.sh ${latestEdition}"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
