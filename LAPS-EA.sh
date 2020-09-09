#!/bin/sh

###################################
# EA to update LAPS Password      #
# deletes the source file as well #
# only updates if value present   #
###################################
udid=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformUUID/ { split($0, line, "\""); printf("%s\n", line[4]); }')
LAPSFileLocation="/usr/local/jamf/$udid/"
LAPSFile="$LAPSFileLocation.$udid"

if [[ -f "$LAPSFile" ]]; then
   value=$(cat $LAPSFile)
   echo "<result>$value</result>"
   else
   value="Not recorded"
fi