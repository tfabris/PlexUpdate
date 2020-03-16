PlexUpdate
==============================================================================

https://github.com/tfabris/PlexUpdate

A script to Auto Update the Plex Media Server on a Synology NAS.
This works around the problem where the built-in auto-update features of
the Synology NAS won't auto-update the Plex Media Server.

Note that, in order for this script to work, Plex Media Server must already be
installed and working on the NAS.

This was originally devised from these two (nearly identical) scripts:

Original author MartinoRob:
- https://github.com/martinorob/plexupdate
- https://forums.plex.tv/t/script-to-auto-update-plex-on-synology-nas-rev4/479748

Some minor formatting improvements by Sean Hamlin:
- https://gist.github.com/seanhamlin/dcde16a164377dca87a798a4c2ea051c

I have added additional logging and bullet-proofing.

------------------------------------------------------------------------------


Configuration
------------------------------------------------------------------------------
####  Obtain and unzip the latest files:
- Download the latest project file and unzip it to your hard disk:
  https://github.com/tfabris/PlexUpdate/archive/master.zip
- (Alternative) Use Git or GitHub Desktop to clone this repository:
  https://github.com/tfabris/PlexUpdate

####  Set file permissions:
Create a folder on the NAS, copy these files to that folder, and set the
access permissions on the folder which contains this script, and the script
itself, using a shell prompt:

     chmod 770 PlexUpdate
     cd PlexUpdate
     chmod 770 *.sh

####  Create automated task to run the script:
On the Synology NAS, in the Synology Task Scheduler, create a
task for this script. Create the job so that it runs PlexUpdate.sh once
per day at your desired time. Configure it to run as root.


Behavior
------------------------------------------------------------------------------
The script will check for a Plex Media Server update on the Synology NAS, and
then install the update if it is a different version than what's currently
installed.

The script will log the most important messages to the Synology system log,
and will print additional detailed debug messages to the console while it
runs.

