#!/bin/zsh


################################################
# local account password change script.        #
# primarily used for standard support account. #
# can be reused if the EA is changed to match. #
################################################
# Version 4
# introduces forced reset back to old password by looping round
# a series of dummy passwords then setting old password again
# has variable receipts for non itvsupport accounts

# set date in standard format for use in EA
now=$(date +"%d/%m/%Y")

# jamf binary path
jamf_binary="/usr/local/jamf/bin/jamf"

##############################################
# ensure required variables are present      #
# if not exit and record fail in policy log. #
##############################################
if [ -n "${4}" ]; then
    setUsername="${4}"
  #  echo "Username = $setUsername"
else
    echo "This script requires a username."
    exit 1
fi

if [ -n "${5}" ]; then
    newPassword="${5}"
   # echo "password = $newPassword"
else
    echo "This script requires a password."
    exit 1
fi

if [ -n "${6}" ]; then
    oldPassword="${6}"
   # echo "old password = $oldPassword"
else
    echo "This script requires a password."
    exit 1
fi

# get first character of password to record in receipt
firstCharacterOfNewPassword=$(echo $newPassword | awk '{print substr($0,0,3)}')

################################################
# functions                                    #
################################################
checkOldPassword () {
# check the oldpassword is valid for the user
passwdA=`dscl /Local/Default -authonly $setUsername $oldPassword`
echo "response is $passwdA"


if [ "$passwdA" == "" ];then
    echo "old Password is correct for $setUsername."
    checkOldPasswordTest="pass"
else
    echo "Error: old Password is not valid for $setUsername."
    #oldPassword=""
    checkOldPasswordTest="fail"
fi

}

resetOldPasswordIfFailed () {
# if old password did not match run round 7 times
# (password age limit) then set to correct old password
# thus ensuring FV works

if [ "$checkOldPasswordTest" = "fail" ]; then

    for i in {1..6}
do
   echo "Changing password to Password$i"
   $jamf_binary resetPassword -username $setUsername -password Zrt45ryPwq$i
   sleep 2
done

# now set the password to the known oldpassword
echo "Changing password to known old password"
   $jamf_binary resetPassword -username $setUsername -password $oldPassword

sleep 2
checkOldPassword
oldPasswordOK="oldwrong"
else
oldPasswordOK="oldgood"
fi

}



changePassword () {
###############################################################
# if oldpass is bad then do a force password change.          #
# downside is users filevault password doesn't change!        #
###############################################################
if [ "$checkOldPasswordTest" = "fail" ];then
    echo "Current password not available, proceeding with forced update."
    $jamf_binary resetPassword -username $setUsername -password $newPassword
    passwordChangeMethod="force"
else
    echo "Updating password for $setUsername."
    $jamf_binary resetPassword -updateLoginKeychain -username $setUsername -oldPassword $oldPassword -password $newPassword
    passwordChangeMethod="good"
fi

}

checkNewPassword () {
passwdB=`dscl /Local/Default -authonly $setUsername $newPassword`

if [ "$passwdB" == "" ];then
    echo "new Password is correct for $setUsername."
    sucessfulPasswordChange="1"
else
    echo "Error: new Password is not valid for $setUsername."
    sucessfulPasswordChange="0"
fi

}

writeReceiptForEA () {


# receipt shows first letter of new password|password change method (good is full method)|whether old password was valid at start
# e.g 4|good|oldgood

if [ "$sucessfulPasswordChange" = "1" ]; then
    echo "$firstCharacterOfNewPassword|$passwordChangeMethod|$oldPasswordOK" > /Library/Receipts/ITV/$setUsername_password_set
    echo "$now" > /Library/Receipts/ITV/$setUsername_password_set_date
else
    echo "FAIL" > /Library/Receipts/ITV/$setUsername_password_set
    echo "$now" > /Library/Receipts/ITV/$setUsername_password_set_date
fi


}




############################################
# script                                   #
############################################
#echo "**************************************"
#echo "**************************************"

#echo " check old password *****"
checkOldPassword


#echo "password test was $checkOldPasswordTest"
resetOldPasswordIfFailed

echo "password test is now $checkOldPasswordTest"

#echo "change password ****"
changePassword

#echo "check new password *****"
checkNewPassword

writeReceiptForEA
