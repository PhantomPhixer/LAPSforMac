# LAPSforMac 2
Local Administrator Password Solution for Mac

## Purpose  

This is a fork of the original [LAPS for Mac](https://github.com/NU-ITS/LAPSforMac) but modified to take in changes to macOS and ways it is now provisioned. 
It provides a way to securely manage the passwords of local admin accounts on macsOS .  The design uses a local Admin account created during a device enrollment build,or manually created if required, on every Mac enrolled into Jamf Pro and stores the account password in the devices inventory record as an Extension Attribute. On a specified interval Jamf will then randomise the local Admin account password and upload into Jamf again.

## Usage Scenarios
This has been tested in the following listed scenarios, but should work in most other ones where there is a known admin user with a known password. *This includes ones where the desired admin user does have a secure token.* 

1. Prestage set to create additional admin and a set user

![prestage](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/prestage-create-account.png)

2. Prestage set create additional admin but skip user creation. Jamf connect will be used to create user accounts.

![prestage](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/prestage-noaccount.png)

In both of these the admin account and initial password are known for use later.

## Components

*LAPSforMac 2* has very few components:

1. A Computer Extension Attribute to hold the current LAPS password.
2. A Smart Group used to identify applicable computers.
3. The LAPS script.
4. Jamf policies that runs the script.
5. A local log for LAPS on each Mac.
6. A local file that stores the password on each Mac.

*Discussion point!* The origianal script used jamf API calls. Recent events have shown having API users can present a security risk as they can not operate behind 2FA.
The design decision for this LAPS is to remove the reliance on APIs and store the password locally, in an obscure way, and allow standard inventory processes to record the password. 
It was initially hoped to delete the local password copy however as the Jamf inventory blanks an EA if no specific result is returned this defeats the whole LAPS purpose as the password would dissappear from Jamf if the file was deleted.

***A lesser of two evils choice!*** 


## Script Variables
   
```{resetUser $4}```  
This is the shortname of the Local Admin account that will be created on macOS devices enrolled in Jamf.  
   
```{basePassword $5}```  
This will be the initial password set in the prestage creating the Local Admin account on the device.  This password is randomised after the policy first runs.  

# Component Setup

## 1. Jamf Computer Extension Attribute

    Display Name: LAPS 
    Description: This attribute will display the current Local Admin Password of the device.  
    Data Type: String  
    Inventory Display: General  
    Input Type: Script 


Copy the contents of LAPS-EA.txt into the script window.

![as shown](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/EA-settings.png)

## 3. Jamf Smart Groups
Replace ```{AccountShortName}``` with the name of the local admin account you will use for LAPS.

	1. Display Name: {AccountShortName} LAPS User Missing
		Criteria: Local User Accounts, does not have, {AccountShortName}

	2. Display Name: {AccountShortName} LAPS User Present
		Criteria: Local User Accounts, has, {AccountShortName}

## 5. LAPS script
	Display Name: LAPS
	Options:
	Priority: After
	Parameter Labels:
		Parameter 4: Admin User
		Parameter 5: Admin Password


### Script
The current version of the LAPS script is available [here](https://github.com/PhantomPhixer/LAPSforMac/blob/master/LAPS.sh).

*Notes: The LAPS script performs the following actions:*  

```
1. Verifies that all variable parameters have been populated within Jamf.  
2. Verifies the location of the JAMF binary.  
3. Verifies that a password is stored in the LAPS extension attribuite within Jamf for this Mac.
	• If no password is found or it is invalid, the script will proceed with a brute force reset of the password.
	• If a password is valid, the script will reset the password and update the local Keychain and FileVault 2.
4. After reseting the password the script will then update the LAPS extension attribute for the Mac in Jamf and verify that the new entry in Jamf is valid on the local Mac.

```


### Variables
```apiURL``` Put the fully qualified domain name address of your Jamf server, including port number  
*(Your port is usually 8443 or 443; change as appropriate for your installation)*

```LogLocation``` Put the preferred location of the log file for this script. If you don't have a preference, using the default setting of ```/Library/Logs/Jamf_Laps.log``` should be fine.  

```newPass``` This function controls the randomized password string. If you don't have a preference, the default should be fine for your environment.

*The diagram below details how the newPass function works, if you wish to modify the password string.*

			   ┌─── openssl is used to create 
			   │	  a random Base64 string
			   │				      ┌── remove ambiguous characters
			   │			          │
	┌──────────┴──────────┐	  ┌───┴────────┐
	openssl rand -base64 10 | tr -d OoIi1lLS | head -c12;echo
											   └──────┬─────┘
											   		  │
	        	prints the first 12 characters	──────┘
	          	of the randomly generated string

		
				
## 6. Jamf LAPS Account Creation Policy
	Display Name: LAPS for {AccountShortName} – Create Local Account – Manual Trigger
	Scope: All Computers
	Trigger:
		Custom: createLAPSaccount-{AccountShortName}
	Frequency: Ongoing
	Local Accounts:
		Action: Create Account
		Username: {AccountShortName}
		Full Name: {AccountDisplayName}
		Password: {AccountInitialPassword}
		Verify Password: {AccountInitialPassword}
		Home Directory Location: /Users/{AccountShortName}/
		Password Hint: (Not Used)
		Allow user to administer computer: Yes
		Enable user for FileVault 2: No	
## 7. Jamf LAPS Account Creation Policy for FileVault 2 Enabled Macs
This is a separate policy to eliminate false positve errors that accumulate in the logs if the Mac is using FileVault 2.

	Display Name: LAPS for {AccountShortName} – Create Local Account FVE – Manual Trigger
	Scope: All Computers
	Trigger:
		Custom: createLAPSaccountFVE-{AccountShortName}
	Frequency: Ongoing
	Local Accounts:
		Action: Create Account
		Username: {AccountShortName}
		Full Name: {AccountDisplayName}
		Password: {AccountInitialPassword}
		Verify Password: {AccountInitialPassword}
		Home Directory Location: /Users/{AccountShortName}/
		Password Hint: (Not Used)
		Allow user to administer computer: Yes
		Enable user for FileVault 2: Yes
## 8. Jamf LAPS Policy – Manual Trigger
This policy randomizes the local admin accounts password after initial account creation.

	Display Name: LAPS for {AccountShortName} - Manual Trigger
	Scope: All Computers
	Trigger: 
		Custom: runLAPS
	Frequency: Once every day (Change this value to meet your institution's needs)
	Scripts: LAPS
		Priority: After
		Parameter Values
			API Username: {APIusername}
			API Password: {APIpassword}
			LAPS Account Shortname: {AccountShortName}
## 9. Jamf LAPS Policy
This policy randomizes the local admin accounts password on a specified interval.

	Display Name: LAPS for {AccountShortName}
	Scope: LAPS {AccountShortName} Account Present
	Trigger: Recurring Check-in
	Frequency: Once every day (Change this value to meet your institution's needs)
	Scripts: LAPS
		Priority: After
		Parameter Values
			API Username: {APIusername}
			API Password: {APIpassword}
			LAPS Account Shortname: {AccountShortName}
## 10. Jamf policy to call the LAPS Account Creation script.
	Name: LAPS – Create Account
	Scope: {AccountShortName} LAPS Account Missing
	Trigger: Startup, Check-in, Enrollment (You may also decide to add a manual trigger for advanced workflows)
	Frequency: Ongoing
	Scripts: LAPS Account Creation
		Priority: Before
		Parameter Values
			API Username: {APIusername}
			API Password: {APIpassword}
			LAPS Account Shortname: {AccountShortName}
			LAPS Account Display Name: {AccountDisplayName}
			LAPS Password Seed: {AccountInitialPassword}
			LAPS Account Event: createLAPSaccount-{AccountShortName}
			LAPS Account Event FVE: createLAPSaccountFVE-{AccountShortName}
			LAPS Run Event: runLAPS
## 11. LAPS Log
A log is written to each Mac run LAPS for troubleshooting. The default location for this log is ```/Library/Logs/Jamf_LAPS.log``` which can be modified if desired.
