#!/bin/bash

# --------------------------------------------------------------------------
# A script to Auto Update the Plex Media Server on a Synology NAS.
# This works around the problem where the built-in auto-update features of
# the Synology NAS won't auto-update the Plex Media Server.
#
# Run this script as Root from your Synology Task Scheduler. Note that, in
# order for this script to work, Plex Media Server must already be installed
# and working on the NAS.
#
# Original author MartinoRob:
#   https://github.com/martinorob/plexupdate
#   https://forums.plex.tv/t/script-to-auto-update-plex-on-synology-nas-rev4/479748
#
# Some minor formatting improvements by Sean Hamlin:
#   https://gist.github.com/seanhamlin/dcde16a164377dca87a798a4c2ea051c
# 
# Additional bulletproofing and logging improvements by Tony Fabris:
#   https://github.com/tfabris/PlexUpdate
# --------------------------------------------------------------------------

# Number of seconds to sleep after installing, before starting Plex server.
sleepAfterInstall=45

# Program name used in log messages.
programname="Plex Update"


#------------------------------------------------------------------------------
# Function blocks
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Function: Log message to console and, if this script is running on a
# Synology NAS, also log to the Synology system log.
# 
# Parameters: $1 - "info"  - Log to console stderr and Synology log as info.
#                  "err"   - Log to console stderr and Synology log as error.
#                  "dbg"   - Log to console stderr, do not log to Synology.
#
#             $2 - The string to log. Do not end with a period, we will add it.
#
# Global Variable used: $programname - Prefix all log messages with this.
#
# NOTE: I'm logging to the STDERR channel (>&2) as a work-around to a problem
# where there doesn't appear to be a Bash-compatible way to combine console
# logging *and* capturing STDOUT from a function call. Because if I log to
# STDOUT, then if I call LogMessage from within any of my functions which
# return values to the caller, then the log message output becomes the return
# data, and messes everything up. TO DO: Learn the correct way of doing both at
# the same time in Bash.
#------------------------------------------------------------------------------
LogMessage()
{
  # Log message to shell console. Echo to STDERR on purpose, and add a period
  # on purpose, to mimic the behavior of the Synology log entry, which adds
  # its own period.
  echo "$programname - $2." >&2

  # Only log to synology if the log level is not "dbg"
  if ! [ "$1" = dbg ]
  then
    # Only log to Synology system log if we are running on a Synology NAS
    # with the correct logging command available. Test for the command
    # by using "command" to locate the command, and "if -x" to determine
    # if the file is present and executable.
    if  [ -x "$(command -v synologset1)" ]
    then 
      # Special command on Synology to write to its main log file. This uses
      # an existing log entry in the Synology log message table which allows
      # us to insert any message we want. The message in the Synology table
      # has a period appended to it, so we don't add a period here.
      synologset1 sys $1 0x11800000 "$programname - $2"
    fi
  fi
}


#------------------------------------------------------------------------------
# Main Program Code
#------------------------------------------------------------------------------

LogMessage "info" "Checking for Plex Media Server update"

# Ensure there is no temporary download folder existing when the program
# starts. Taking extra measures to make sure that the download folder does not
# exist both before and after the update, so that we can be sure that it does
# not  accidentally grow in size over time.
rm -rf /tmp/PlexTempDownload/

# Obtain and validate the Plex token value from the existing installation.
TOKEN=$(cat /volume1/Plex/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | grep -oP 'PlexOnlineToken="\K[^"]+')
if [ ! -z $TOKEN ] && [ $TOKEN != null ]
then
  LogMessage "dbg" "Token successfully retrieved: $TOKEN"
else
  LogMessage "err" "Unable to retrieve token"
  exit 1
fi

# Obtain and validate the JSON of the available versions of Plex from the Internet.
URL=$(echo "https://plex.tv/api/downloads/5.json?channel=plexpass&X-Plex-Token=${TOKEN}")
JSON=$(curl -s ${URL})
if [ ! -z "$JSON" ]
then
  LogMessage "dbg" "JSON successfully retrieved"
else
  LogMessage "err" "Unable to retrieve JSON"
  exit 1
fi

# Retrieve and validate the currently installed version of Plex on the NAS.
CURRENT_VERSION=$(synopkg version "Plex Media Server")
if [ ! -z "$CURRENT_VERSION" ] && [ $CURRENT_VERSION != null ]
then
  LogMessage "info" "Current version:   ${CURRENT_VERSION}"
else
  LogMessage "err" "Unable to retrieve current version of installed Plex package"
  exit 1
fi

# Parse and validate the newest available version out of the JSON.
NEW_VERSION=$(echo $JSON | jq -r .nas.Synology.version)
if [ ! -z "$NEW_VERSION" ] && [ $NEW_VERSION != null ]
then
  LogMessage "info" "New version:       ${NEW_VERSION}"
else
  LogMessage "err" "Unable to retrieve new version out of the JSON"
  exit 1
fi

# For debugging use only.
#   LogMessage "dbg" "$JSON"

# Parse and validate the datestamp of the new version out of the JSON.
NEW_DATE=$(echo $JSON | jq -r .nas.Synology.release_date)
if [ ! -z "$NEW_DATE" ] && [ $NEW_DATE != null ]
then
  LogMessage "dbg" "New version date:  ${NEW_DATE}"
else
  LogMessage "err" "Unable to retrieve new date out of the JSON"
  exit 1
fi
NEW_DATE_STRING=$( date -d @$NEW_DATE +'%Y-%m-%d' )

# Test if the new version on the Internet is different from the installed version.
if [ "${NEW_VERSION}" != "${CURRENT_VERSION}" ]
then
  # Log to the system log that an update is going to happen.
  LogMessage "info" "New Plex version available, updating Plex to version ${NEW_VERSION} dated ${NEW_DATE_STRING}"

  # This synonotify doesn't seem to be working quite right. It puts up a
  # bubble notification on the Synology user interface, but the notification
  # doesn't contain information like the company or the name of the package. 
  # Since I don't need/care about this notification myself, I'm disabling it.
  #    synonotify PKGHasUpgrade '{"[%HOSTNAME%]": $(hostname), "[%OSNAME%]": "Synology", "[%PKG_HAS_UPDATE%]": "Plex", "[%COMPANY_NAME%]": "Synology"}'

  # Obtain and validate the current processor architecture for the Synology NAS.
  CPU=$(uname -m)
  if [ ! -z "$CPU" ] && [ $CPU != null ]
  then
    LogMessage "dbg" "CPU architecture: ${CPU}"
  else
    LogMessage "err" "Unable to determine CPU architecture"
    exit 1
  fi

  # Parse and validate the final download URL of the correct architecture.
  URL=""
  if [ "$CPU" = "x86_64" ] ; then
    URL=$(echo $JSON | jq -r ".nas.Synology.releases[1] | .url")
  else
    URL=$(echo $JSON | jq -r ".nas.Synology.releases[0] | .url")
  fi
  if [ ! -z "$URL" ]
  then
    LogMessage "dbg" "Download URL: ${URL}"
  else
    LogMessage "err" "Unable to determine download URL"
    exit 1
  fi

  # Create temporary folder for the download, and ensure no error was
  # encountered. An error creating the download folder would indicate that the
  # prior attempts to clean this folder had failed, and so this script should
  # not attempt to download more things. Otherwise the folder would just grow
  # over time.
  LogMessage "dbg" "Creating temporary download folder"
  mkdir -p /tmp/PlexTempDownload/
  if [ $? -eq 0 ]
  then
    LogMessage "dbg" "Temporary download folder created"
  else
    LogMessage "err" "Unable to create temporary download folder"
    exit 1
  fi

  LogMessage "dbg" "Downloading package file"
  wget $URL -P /tmp/PlexTempDownload/
  if [ $? -eq 0 ]
  then
    LogMessage "dbg" "File was downloaded"
  else
    LogMessage "err" "There was an error downloading the file"
    exit 1
  fi

  LogMessage "dbg" "Installing package"
  synopkg install /tmp/PlexTempDownload/*.spk
  if [ $? -eq 0 ]
  then
    LogMessage "dbg" "Package was installed"
  else
    LogMessage "err" "There was an error installing the package"
    exit 1
  fi

  LogMessage "dbg" "Pausing $sleepAfterInstall seconds before starting service"
  sleep $sleepAfterInstall

  LogMessage "dbg" "Starting service"
  synopkg start "Plex Media Server"
  if [ $? -eq 0 ]
  then
    LogMessage "dbg" "Service started"
  else
    LogMessage "err" "There was an error starting the service"
    exit 1
  fi  
else
  LogMessage "info" "Plex Media Server is up to date. Installed version is $CURRENT_VERSION, new version is $NEW_VERSION dated $NEW_DATE_STRING"
fi

LogMessage "dbg" "Deleting temporary download folder if it exists"
rm -rf /tmp/PlexTempDownload/

LogMessage "dbg" "Update complete"
exit 0