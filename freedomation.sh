#!/bin/bash

updating_comp() {
   echo "Press Enter whenever prompted to perform default actions."
   sleep 5
   sudo sh -c 'apt-get update; apt-get upgrade -y; apt-get dist-upgrade -y; apt-get autoremove -y; apt-get autoclean -y'
   echo "Updating components are finished. Preparing to install requirement utils..."
   sleep 4
}

installing_comp(){
   echo "Gathering requirements to install..."
   sleep 1
   sudo apt-get install -y software-properties-common ufw wget curl git socat cron busybox bash-completion locales nano apt-utils
   echo "Installing components are finished."
}

MIN_PORT=49152
MAX_PORT=65535
OLD_PORT="#Port 22"

echo "Checking SSH port has been changed lately or not..."
sleep 3
if grep -q "$OLD_PORT" /etc/ssh/sshd_config; then  # Check if sshd_config file has been changed yet or not
   while true; do
      read -p "Do you want to change SSH port at first? (Recommanded) [y/n] " response # Prompt the user for a port number
      sleep 1
      case "$response" in
         y|Y|Yes|YES|yes)
            read -p "Enter a port number for SSH (between $MIN_PORT and $MAX_PORT): " port 
            if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge $MIN_PORT && $port -le $MAX_PORT ]]; then # Check if the input is a valid port number within the range
               echo "Valid port number entered: $port. Preparing for change..."  
               sleep 2
               sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak # Create a backup
                  if [ $? -eq 0 ]; then # Check if the backup was successful
                     echo "Backup of SSHD Config created successfully."
                  else
                     echo "Backup of SSHD Config creation failed."
                  fi
               sleep 2
               sudo sed -i "s/$OLD_PORT/Port $port/g" /etc/ssh/sshd_config
               echo "Changing SSHD port done. Reloading service..."
               sleep 2
               sudo systemctl reload sshd
               sleep 2
               echo "Everything done. Preparing for updating server components..."
               sleep 3
               updating_comp
               installing_comp
               break
            else 
               echo "Invalid port number. Please try again with a valid port within the range."
               sleep 2
               fi   
            ;;
         n|N|No|NO|no)
            echo "Strongly recommanded change SSH port customizably later! Preparing for updating server components... "
            sleep 3
            updating_comp
            installing_comp
            break
            ;;
         *)
            echo "Invalid answer. Please input Y/y for changing port or N/n to avoid changing port now."
            sleep 2
            ;;
      esac
   done
else
   echo "You have been changed default SSH port on this server! Preparing for updating server components..."
   sleep 3
   updating_comp
   installing_comp
fi