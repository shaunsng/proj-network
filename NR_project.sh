#!/bin/bash

# Shaun's script for CFC NR Project

#~ 1. Check if following apps needed for the script are installed, and install them if not found. 
	#~ a. geoip-bin
	#~ b. tor
	#~ c. sshpass
	#~ d. nipe

# Retrieve record of installed apps and output to text file for checking later in script. 
apt-mark showinstall > installed.txt

# Saving directory where script is run as variable, to facilitate navigation later on.   
start=$(pwd)

# Run loop to check if first three apps are installed, and install them if not.
apps=('geoip-bin' 'tor' 'sshpass')
for app in "${apps[@]}"

do
   # Use string match to check if app names are listed in apt-mark.
   result=$(cat installed.txt | grep -x $app)
   if [ $result == $app ]
   then
	echo "[+] $app is already installed"
   else
	echo "[-] $app was not found. Installing now."
	echo "kali" | sudo -S apt-get install $app
	sleep 1
   fi
          
done

# As installing nipe requires several steps, we process this separately from other apps.
# We search for nipe.pl file to check if it is installed, as it does not appear on apt-list or apt-mark records even when available.

echo "kali" | sudo -S updatedb
nipefile=$(locate nipe.pl)

if [ -z "$nipefile" ]

then
	# Installation steps if nipe not found.
	echo "[-] Nipe was not found. Installing now."
	git clone https://github.com/htrgouvea/nipe && cd $start/nipe
	sudo apt-get install cpanminus
	cpanm --installdeps .
	sudo cpan install Switch JSON LWP::UserAgent Config::Simple
	sudo perl nipe.pl install 
	sleep 2
	
else
	echo "[+] Nipe is already installed."
	# Earlier saved location of search is also useful to help us enter directory where nipe is already installed.
	cd $(dirname $nipefile)

fi

#~ 2. Connect through Nipe and once connected(anonymous), display the spoofed IP and Country.
#~ a. If we are unable to connect, let the user know then exit the script right away.
    
echo
echo "[➔] All apps ready. Attempting to connect anonymously..." 
echo
sleep 2

# We attempt to connect to nipe, save status and check if connection successful using keyword "true".

sudo perl nipe.pl start
sudo perl nipe.pl status > nipestatus.txt
nipetrue=$( cat nipestatus.txt | grep true) 

if [ ! -z "nipetrue" ]
then
	echo "[☺] Anonymous connection successful!"
	
	# Retrieving IP and country info to show user.
	IPadd=$(cat nipestatus.txt | grep Ip | awk '{print$3}')
	Country=$(geoiplookup $IPadd | awk -F: '{print$2}')
	echo "[➔] Your spoofed IP address is: $IPadd"
	echo "[➔] Your spoofed country is: $Country"
	
else
	echo "[☹] Failed to make anonymous connection. This script will now exit. Please try again later."
fi
    
#~ 3. Get the user’s input for the domain/url to scan

# Straightforward query and saving domain/IP as variable.

echo
echo "[?] Specify a domain or IP address to scan."
read IPcheck

#~ 4. Connect to the remote server via ssh.(`sshpass`)

serverIP='192.168.133.128'
echo "[➔] Connecting to server:"    

#~ a. We will then scan the domain/url provided by the user ON THE REMOTE SERVER.
#~ b. Save the result of the scan onto the remote server(Ubuntu).
  
# Access remote server with known credentials. Using sshpass so no password prompt needed.
# EOF delimiter to organise multiple commands to be executed on server. 

sshpass -p "tc" ssh tc@$serverIP <<EOF
	echo 
	echo "Successfully logged on to remote server."
	echo
	sleep 2
	echo "Server uptime: $(uptime)"
	echo "IP address: $serverIP"
	echo "Country: $(geoiplookup $serverIP | awk -F: '{print$2}')"
	echo
	echo "Whois check running on specified domain/address..."
	TZ='Singapore' date >> scan.log
	echo $IPcheck >> scan.log
	whois $IPcheck >> scan.log
	echo >> scan.log
	echo "$(TZ='Singapore' date) - whois data for: $IPcheck collected in current directory in scan.log"

EOF

#~ 5. We will want to have a log file to record the domain/URL scanned. 
# Remember to include the day, date and time. And of course the domain/URL that was scanned.

# Running sshpass + securecopy to retrieve the log from server to local machine.

sshpass -p "tc" scp tc@$serverIP:/home/tc/scan.log $start

# Removing the temporary files we created to reduce trace of activity.
rm $start/nipe/nipestatus.txt
rm $start/installed.txt

echo "This script has completed. Have a nice day."

