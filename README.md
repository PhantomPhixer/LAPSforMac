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

## 2. Jamf Smart Group
Replace ```{Admin user name}``` with the name of the local admin account required.

	Display Name: {Admin user name} LAPS User Present
	Criteria: Local User Accounts, has, {Admin user name}

![as shown](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/sg2.png)

## 3. LAPS script
	Display Name: LAPS
	Options:
	Priority: After
	Parameter Labels:
		Parameter 4: Admin user name
		Parameter 5: Admin base password

![as shown](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/script.png)
### Script
The current version of the LAPS script is available [here](https://github.com/PhantomPhixer/LAPSforMac/blob/master/LAPS.sh).

*Notes: The LAPS script performs the following actions:*  

```
1. Verifies that all variable parameters have been populated within Jamf.  
2. Checks if the password has been set by the script on this machine.
	• If it has this is used as the base password overriding the default base password.
	• The base password is only required if the admin account has a secure token. Ff it doesn't, and in the scenarios this is tested against it shouldn't have, then the base password is never used.
3. After reseting, and verifying, the password the script will then update the extension attribute by running a *jamf recon*.

```

### Variables
Two variables are set in the script itself.

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

		
				

## 6. Jamf LAPS Policy – Manual Trigger (*Optional*)
This policy randomises the local admin accounts password using a trigger.
Can be called in build scripts to ensure device is compliant during the build process or can be called from from any other policy as required.

	Display Name: LAPS for {Admin user name} - Manual Trigger
	Scope: All Computers
	Trigger: 
		Custom: runLAPS
	Frequency: Ongoing (as it's manual trigger this is ok)
	Scripts: LAPS
		Priority: After
		Parameter Values
			Admin username
			Admin base password

![policy-triggered](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/policy-manual.png)

![policy-script](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/policy-script.png)

## 7. Jamf LAPS Policy - Scheduled
This policy randomises the local admin accounts password on a specified interval.

	Display Name: LAPS for {Admin user name}
	Scope: {Admin user name} LAPS User Present
	Trigger: Recurring Check-in
	Frequency: Once every day/week/month (Change this value to meet your institution's needs)
	Scripts: LAPS
		Priority: After
		Parameter Values
			Admin username
			Admin base password

![policy-scheduled](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/policy-scheduled.png)

![policy-scoped](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/policy-scope.png)

![policy-script](https://github.com/PhantomPhixer/LAPSforMac/blob/master/images/policy-script.png)

## 8. LAPS Log
A log is written to each Mac run LAPS for troubleshooting. The default location for this log is ```/Library/Logs/Jamf_LAPS.log``` which can be modified if desired.
