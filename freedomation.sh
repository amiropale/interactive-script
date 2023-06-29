#!/bin/bash

updating_comp() {
   echo "Press Enter whenever prompted to perform default actions."
   sleep 5
   sudo sh -c 'apt-get update; apt-get upgrade -y; apt-get dist-upgrade -y; apt-get autoremove -y; apt-get autoclean -y'
   echo "Updating components are finished. Preparing to install requirement utils..."
   sleep 4
}

installing_comp() {
   echo "Gathering requirements to install..."
   sleep 1
   sudo apt-get install -y software-properties-common ufw wget curl git socat cron busybox bash-completion locales nano apt-utils
   echo "Installing components are finished."
   sleep 4
}

installing_docker_dc_comp() {
   read -rsn1 -p "Now installing Docker and Docker-Compose for running services. Press any key to continue otherwise if you have had installed Docker and Docker-Compose press Esc to ignore this section..." key
   if [[ $key == $'\x1b' ]]; then
      echo -e "\nYou chose to ignoring this section and canceled the procedure of docker setup now.\nNow please wait for SSL gathering section to be load!"
      sleep 5
      acme_ssl
   else
      echo -e "\nStarting to install docker-setup.sh, please wait..."
      sleep 5
      sudo wget --quiet get.docker.com -O docker-setup.sh && sh docker-setup.sh
      sleep 3
      echo "Docker has been installed successfully on server. Now preparing to install Docker-Compose..."
      sleep 3
      LATEST_VERSION=$(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
      sudo curl -L "https://github.com/docker/compose/releases/download/${LATEST_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
      sleep 2
      echo "Docker-Compose has been installed and configured successfully."
      sleep 4
   fi
}

acme_ssl() {
   echo "Getting SSL license with acme.sh from letsencrypt corp..."
   sleep 2
   read -p "Please enter your Email address to set acme.sh configuration: " email
   sleep 1
   sudo curl https://get.acme.sh | sh -s email="$email"
   sudo source  ~/.bashrc
   echo "Setting config..."
   sleep 2
   sudo acme.sh --set-default-ca --server letsencrypt
   sudo acme.sh --register-account -m "$email"
   sudo acme.sh --upgrade --auto-upgrade
   sleep 1
   echo -e "SSL certificate has been added to server by acme.sh script.\n"
   sleep 1
   echo -e "System needs to restart now. After 10 sec your PC shuts down and reboot.\nYou can run next script to install x-ui panel."
   echo -e "\nSleep 10s"
   sleep 10
   echo -e "\nRebooting machine..."
   sleep 1
   sudo shutdown -r now
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
            if [[ $port =~ ^[0-9]+$ ]] && ((port >= MIN_PORT))  &&  ((port <= MAX_PORT)); then # Check if the input is a valid port number within the range
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
               installing_docker_dc_comp
               acme_ssl
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
            installing_docker_dc_comp
            acme_ssl
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
   installing_docker_dc_comp
   acme_ssl
fi
