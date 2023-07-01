#!/bin/bash

sshd_change_check() {
   echo -e "\nChecking SSH port has been changed recently or not...\n"
   sleep 3
   if ! grep -q "^#Port" /etc/ssh/sshd_config && ! grep -q "^Port" /etc/ssh/sshd_config; then
      change_prompt   
   elif grep -q "^#Port" /etc/ssh/sshd_config && ! grep -q "^Port" /etc/ssh/sshd_config; then
      change_prompt
   elif [ "$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')" == "22" ] && ! grep -q "^#Port" /etc/ssh/sshd_config; then
      change_prompt
   else
      echo -e "SSH port has been changed from the default port. Preparing for updating server components...\n"
      sleep 3
      updating_comp
      installing_comp
      opt_1
   fi
}

change_prompt() {
   MIN_PORT=49152
   MAX_PORT=65535
   echo -e "SSH port is set to the default port.\n"
   sleep 1
   read -p "Do you want to change SSH port at first? (Recommanded) [Y/n] " response # Prompt the user for a port number
   while true; do
      case "$response" in
         y|Y|Yes|YES|yes)
            read -p "Enter a port number for SSH (between $MIN_PORT and $MAX_PORT): " port 
            if [[ $port =~ ^[0-9]+$ ]] && ((port >= MIN_PORT))  &&  ((port <= MAX_PORT)); then # Check if the input is a valid port number within the range
               echo -e "Valid port number entered: $port. Preparing for change...\n"  
               sleep 2
               changing_port
               updating_comp
               installing_comp
               opt_1
               break
            else 
               echo -e "Invalid port number. Please try again with a valid port within the range.\n"
               sleep 2
            fi   
            ;;
         n|N|No|NO|no)
            echo -e "Strongly recommanded change your SSH port customizably later! Preparing for updating server components...\n"
            sleep 3
            updating_comp
            installing_comp
            opt_1
            break
            ;;
         *)
            echo -e "Invalid answer. Please input Y/y for changing port or N/n to avoid changing port now.\n"
            sleep 2
            ;;
      esac
   done
}

changing_port() {
   old_port=22
   current_port1=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}') # Get the current SSH port
   current_port2=$(grep -E "^#Port" /etc/ssh/sshd_config | awk '{print $2}') # Get the current SSH port
   sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak # Create a backup
   if [ $? -eq 0 ]; then # Check if the backup was successful
      echo -e "Backup of SSHD Config created successfully.\n"
   else
      echo -e "Backup of SSHD Config creation failed.\n"
   fi
   sleep 2
   sudo sed -i "s/$current_port1/Port $port/g" /etc/ssh/sshd_config
   sudo sed -i "s/$current_port2/Port $port/g" /etc/ssh/sshd_config
   echo -e "Changing SSH port done. Reloading service...\n"
   sleep 2
   sudo systemctl reload sshd
   sleep 2
   echo -e "Everything done. Preparing for updating server components...\n"
   sleep 3
}

updating_comp() {
   echo -e "\nPress Enter whenever prompted to perform default actions.\n"
   sleep 5
   sudo sh -c 'apt-get update; apt-get upgrade -y; apt-get dist-upgrade -y; apt-get autoremove -y; apt-get autoclean -y'
   echo -e "\nUpdating components are finished. Preparing to install requirement utils...\n"
   sleep 4
}

installing_comp() {
   echo -e "\nGathering requirements to install...\n"
   sleep 1
   sudo apt-get install -y software-properties-common ufw wget curl git socat cron busybox bash-completion locales nano apt-utils
   echo -e "\nInstalling components are finished.\n"
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
      echo -e "\nDocker has been installed successfully on server. Now preparing to install Docker-Compose...\n"
      sleep 3
      LATEST_VERSION=$(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
      sudo curl -L "https://github.com/docker/compose/releases/download/${LATEST_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
      sleep 2
      echo -e "\nDocker-Compose has been installed and configured successfully.\n"
      sleep 4
   fi
}

acme_ssl() {
   echo -e "\nGetting SSL license with acme.sh from letsencrypt corp...\n"
   sleep 2
   read -p "Please enter your Email address to set acme.sh configuration: " email
   sleep 1
   sudo curl https://get.acme.sh | sh -s email="$email"
   source  ~/.bashrc
   echo -e "\nSetting config...\n"
   sleep 2
   acme.sh --set-default-ca --server letsencrypt
   acme.sh --register-account -m "$email"
   acme.sh --upgrade --auto-upgrade
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

opt_1() {
   read -p "Do you want to config UFW (Uncomplicated Firewall for linux) with a higher security to avoid all incoming connections? (Optional) [Y/n]" res1
   while true; do
      if [[ $res1 == y || $res1 == Y || $res1 == Yes || $res1 == YES || $res1 == yes ]]; then
         echo -e "\nDenying all incoming connections...\n"
         sleep 1
         sudo ufw default deny incoming
         echo -e "Allowing outgoing and limit SSH port given before...\n"
         sleep 1
         sudo ufw default allow outgoing
         sudo ufw limit $port
         echo y | sudo ufw enable
         echo -e "UFW successfully configured.\n"
         sleep 1
         opt_2
         break
      elif [[ $res1 == n || $res1 == N || $res1 == No || $res1 == NO || $res1 == no ]]; then
         echo -e "You have chosen to pass this section. Now you will prompt for server optimizations...\n"
         sleep 1
         opt_2
         break
      else
         echo -e "Invalid answer. Please input Y/y for configuring UFW or N/n to avoid configuring now.\n"
      fi
   done
}

opt_2() {
   read -p "Do you want use Hybla instead of BBR method for TCP connections for even more speed? (Optional) [Y/n] " -res2
   while true; do
      if [[ $res2 == y || $res2 == Y || $res2 == Yes || $res2 == YES || $res2 == yes ]]; then
         echo -e "Adding some changes to limits.conf ...\n"
         sleep 1
         sudo bash -c 'echo "* soft nofile 51200" >> /etc/security/limits.conf && echo "* hard nofile 51200" >> /etc/security/limits.conf'
         ulimit -n 51200
         echo -e "Adding Hybla instructions to UFW services...\n"
         sleep 1
         sudo bash -c 'cat << EOF >> /etc/ufw/sysctl.conf
         fs.file-max = 51200
         net.core.rmem_max = 67108864
         net.core.wmem_max = 67108864
         net.core.netdev_max_backlog = 250000
         net.core.somaxconn = 4096
         net.ipv4.tcp_syncookies = 1
         net.ipv4.tcp_tw_reuse = 1
         net.ipv4.tcp_tw_recycle = 0
         net.ipv4.tcp_fin_timeout = 30
         net.ipv4.tcp_keepalive_time = 1200
         net.ipv4.ip_local_port_range = 10000 65000
         net.ipv4.tcp_max_syn_backlog = 8192
         net.ipv4.tcp_max_tw_buckets = 5000
         net.ipv4.tcp_fastopen = 3
         net.ipv4.tcp_mem = 25600 51200 102400
         net.ipv4.tcp_rmem = 4096 87380 67108864
         net.ipv4.tcp_wmem = 4096 65536 67108864
         net.ipv4.tcp_mtu_probing = 1
         net.ipv4.tcp_congestion_control = hybla
         EOF'
         echo -e "Hybla method successfully replaced with BBR method.\n"
         sleep 1
         installing_docker_dc_comp
         acme_ssl
         break
      elif [[ $res2 == n || $res2 == N || $res2 == No || $res2 == NO || $res2 == no ]]; then
         echo -e "You have chosen to pass this section. Now preparing to install Docker...\n"
         sleep 1
         installing_docker_dc_comp
         acme_ssl
         break
      else
         echo -e "Invalid answer. Please input Y/y for optimizing server or N/n to avoid optimization now.\n"
      fi
   done
}


#=====================================START-HINT=========================================
echo "---------------------------------------------------------------------------------"
echo "------------------ Rahgozar/Freedom repo Automated Script 1 ---------------------"
echo "This is the first interactive-script for running"
echo "x-ui xray service on linux servers. BTW, 6 below"
echo "sections are going to do the procedure. At last,"
echo "your PC will reboot automatically and you have to"
echo "run next script to continue procedure... : "
echo -e "\n"
echo -e "1- Checking OS if any changes have been made to SSH default port and set it done (Recommanded)."
echo -e "\n"
echo -e "2- Updating mirrors and installing some necessary utils."
echo -e "\n"
echo -e "3- Installing Docker and Docker-compose to running multiple services easily (You will prompt to jump this section if you have already installed Docker)."
echo -e "\n"
echo -e "4- Getting SSL Cert for server with acme.sh."
echo -e "\n"
echo -e "+++++++++++++OPTIONALS++++++++++++++"
echo -e "\n"
echo -e "Optional 1- Firewall configurations."
echo -e "Optional 2- Server optimizations."
echo "---------------------------------------------------------------------------------"
#=========================================================================================

read -rsn1 -p "Press any key to continue or ESC to exit..." key
   if [[ $key == $'\x1b' ]]; then
      echo -e "\nExiting...\n"
      sleep 2
      exit 0
   else
      sleep 1
      sshd_change_check
   fi