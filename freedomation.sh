#!/bin/bash

echo -e "Setting up environment...\n"
sleep 1
export LE_WORKING_DIR="/root/.acme.sh"

sshd_change_check() {
   echo ""
   echo -e "\n-----Checking SSH port has been changed recently or not...\n"
   sleep 1
   if ! grep -q "^#Port" /etc/ssh/sshd_config && ! grep -q "^Port" /etc/ssh/sshd_config; then
      change_prompt   
   elif grep -q "^#Port" /etc/ssh/sshd_config && ! grep -q "^Port" /etc/ssh/sshd_config; then
      change_prompt
   elif [ "$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')" == "22" ] && ! grep -q "^#Port" /etc/ssh/sshd_config; then
      change_prompt
   else
      echo -e "-----SSH port has been changed from the default port. Preparing for updating server components...\n"
      sleep 1
      updating_comp
      installing_comp
      opt_1
   fi
}

change_prompt() {
   MIN_PORT=49152
   MAX_PORT=65535
   echo -e "-----SSH port is set to the default port.\n"
   sleep 1
   read -p "+++++Do you want to change SSH port at first? (Recommanded) [Y/n] " response # Prompt the user for a port number
   echo ""
   while true; do
      case "$response" in
         y|Y|Yes|YES|yes)
            read -p "+++++Enter a port number for SSH (between $MIN_PORT and $MAX_PORT): " port 
            if [[ $port =~ ^[0-9]+$ ]] && ((port >= MIN_PORT))  &&  ((port <= MAX_PORT)); then # Check if the input is a valid port number within the range
               echo -e "\n-----Valid port number entered: $port. Preparing for change...\n"  
               sleep 1
               changing_port
               updating_comp
               installing_comp
               opt_1
               break
            else 
               echo -e "\n-----Invalid port number entered. Please try again with a valid port within the range.\n"
               sleep 1
            fi   
            ;;
         n|N|No|NO|no)
            echo -e "\n-----Strongly recommanded change your SSH port customizably later! Preparing for updating server components...\n"
            sleep 1
            updating_comp
            installing_comp
            opt_1
            break
            ;;
         *)
            echo -e "\n-----Invalid answer. Please input Y/y for changing port or N/n to avoid changing port now.\n"
            sleep 1
            change_prompt
            ;;
      esac
   done
}

changing_port() {
   current_port1=$(grep "^Port" /etc/ssh/sshd_config) # Get the current SSH port
   current_port2=$(grep "^#Port" /etc/ssh/sshd_config) # Get the current SSH port
   echo -e "\n-----Creating SSHD backup file...\n"
   sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak # Create a backup
   if [ $? -eq 0 ]; then # Check if the backup was successful
      echo -e "-----Backup of SSHD Config created successfully.\n"
   else
      echo -e "-----Backup of SSHD Config creation failed.\n"
   fi
   echo -e "\n-----Now wait for changing SSH port...\n"
   sleep 1
   sudo sed -i -E "s/$current_port1/Port $port/g" /etc/ssh/sshd_config 2&>/dev/null
   sudo sed -i -E "s/$current_port2/Port $port/g" /etc/ssh/sshd_config 2&>/dev/null
   echo -e "\n-----Changing SSH port done. Reloading service...\n"
   sleep 1
   sudo systemctl reload sshd
   sleep 1
   echo -e "\n-----Preparing for updating server components...\n"
   sleep 1
}

updating_comp() {
   echo -e "\n+++++Press Enter whenever prompted to perform default actions."
   echo -e "+++++Please Enter password for root if prompted to perform default actions.\n"
   sleep 1
   sudo sh -c 'apt-get update; apt-get upgrade -y; apt-get dist-upgrade -y; apt-get autoremove -y; apt-get autoclean -y'
   echo -e "\n-----Updating components are finished. Preparing to install requirement utils...\n"
   sleep 1
}

installing_comp() {
   echo -e "\n-----Gathering requirements to install...\n"
   sleep 1
   sudo apt-get install -y software-properties-common ufw wget curl git socat cron busybox bash-completion locales nano apt-utils
   echo -e "\n-----Installing components are finished.\n"
   sleep 1
}

installing_docker_dc_comp() {
   read -rsn1 -p "+++++Now installing Docker and Docker-Compose for running services. Press any key to continue otherwise if you have had installed Docker and Docker-Compose press Esc to ignore this section..." key
   if [[ $key == $'\x1b' ]]; then
      echo -e "\n\n-----You chose to ignoring this section and canceled the procedure of docker setup now.\n\n-----Now please wait for SSL gathering section to be load!"
      sleep 1
      acme_ssl
      exit_status=$?
      echo "$exit_status" > /tmp/status_file.txt
      reboot
   else
      echo -e "\n\n-----Starting to install docker-setup.sh, please wait..."
      sleep 1
      sudo wget --quiet get.docker.com -O docker-setup.sh && sh docker-setup.sh
      sleep 1
      echo -e "\n\n-----Docker has been installed successfully on server. Now preparing to install Docker-Compose...\n"
      sleep 1
      LATEST_VERSION=$(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
      sudo curl -L "https://github.com/docker/compose/releases/download/${LATEST_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
      sleep 1
      echo -e "\n\n-----Docker-Compose has been installed and configured successfully.\n"
      sleep 1
      acme_ssl
      exit_status=$?
      echo "$exit_status" > /tmp/status_file.txt
      reboot
   fi
}

acme_ssl() {
   echo -e "\n-----Getting SSL license with acme.sh from letsencrypt corp...\n"
   sleep 1
   read -p "+++++Please enter your Email address to set acme.sh configuration: " email
   sleep 1
   echo -e "\n-----Installing acme.sh script on your machine...\n"
   sudo curl -o /root/acme.sh https://get.acme.sh
   sudo chmod +x /root/acme.sh
   sudo /root/acme.sh email="$email"
   echo -e "\n-----Setting config...\n"
   sleep 1
   sudo /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
   sudo /root/.acme.sh/acme.sh --register-account -m "$email"
   sudo /root/.acme.sh/acme.sh --upgrade --auto-upgrade
   sleep 1
   echo -e "-----SSL certificate has been added to server by acme.sh script.\n"
   sleep 1
   echo -e "+++++System needs to restart now. After 10 sec your PC shuts down and reboot.\nAfter that the script will re-run automatically to install x-ui panel."
   echo -e "\n+++++Sleep 10s"
   sleep 10
   echo -e "\n-----Rebooting machine..."
   sleep 1
   return 100
}

reboot() {
   mk_service
   sudo shutdown -r now
}

opt_1() {
   read -p "+++++Do you want to config UFW (Uncomplicated Firewall for linux) with a higher security to avoid all incoming connections? (Optional) [Y/n]" res1
   while true; do
      if [[ $res1 == y || $res1 == Y || $res1 == Yes || $res1 == YES || $res1 == yes ]]; then
         echo -e "\n-----Denying all incoming connections...\n"
         sleep 1
         sudo ufw default deny incoming
         echo -e "-----Allowing outgoing and limit SSH port given before...\n"
         sleep 1
         sudo ufw default allow outgoing
         sudo ufw limit $port
         echo y | sudo ufw enable
         echo -e "-----UFW successfully configured.\n"
         sleep 1
         opt_2
         break
      elif [[ $res1 == n || $res1 == N || $res1 == No || $res1 == NO || $res1 == no ]]; then
         echo -e "\n-----You have chosen to pass this section. Now you will prompt for server optimizations...\n"
         sleep 1
         opt_2
         break
      else
         echo -e "\n-----Invalid answer. Please input Y/y for configuring UFW or N/n to avoid configuring now.\n"
         opt_1
      fi
   done
}

opt_2() {
   read -p "+++++Do you want use Hybla instead of BBR method for TCP connections for even more speed? (Optional) [Y/n] " res2
   while true; do
      if [[ $res2 == y || $res2 == Y || $res2 == Yes || $res2 == YES || $res2 == yes ]]; then
         echo -e "-----Adding some changes to limits.conf ...\n"
         sleep 1
         sudo bash -c 'echo "* soft nofile 51200" >> /etc/security/limits.conf && echo "* hard nofile 51200" >> /etc/security/limits.conf'
         ulimit -n 51200
         echo -e "-----Adding Hybla instructions to UFW services...\n"
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
         sudo sed -i '$ d' /etc/ufw/sysctl.conf
         echo -e "-----Hybla method successfully replaced with BBR method.\n"
         sleep 1
         installing_docker_dc_comp
         break
      elif [[ $res2 == n || $res2 == N || $res2 == No || $res2 == NO || $res2 == no ]]; then
         echo -e "\n-----You have chosen to pass this section. Now preparing to install Docker...\n"
         sleep 1
         installing_docker_dc_comp
         break
      else
         echo -e "\n-----Invalid answer. Please input Y/y for optimizing server or N/n to avoid optimization now.\n"
         opt_2
      fi
   done
}

mk_service() {
   script_dir=$(dirname "$(readlink -f "$0")")
   sudo bash -c "cat << EOF >> /etc/systemd/system/freedomation.service
   
   [Unit]
   Description=Reboot Service for Freedomation Interactive Script
   After=network.target

   [Service]
   ExecStart=/bin/bash $script_dir/freedomation.sh

   [Install]
   WantedBy=multi-user.target
   EOF"
   sudo sed -i '$ d' /etc/systemd/system/freedomation.service
   sudo systemctl daemon-reload
   sudo systemctl enable freedomation.service
}

rm_service() {
   echo -e "\nPlease enter root password for removing script auto reboot service...\n"
   service_name="freedomation.service"
   sudo systemctl stop $service_name
   sudo systemctl disable $service_name
   sudo rm /etc/systemd/system/$service_name
   sudo systemctl daemon-reload
   sudo systemctl reset-failed
}

status_file() {
   status_file="/tmp/status_file.txt"
   if [ -f "$status_file" ]; then
      exit_status=$(cat "$status_file")
      if [ "$exit_status" -eq 100 ]; then
         rm /tmp/status_file.txt
         install_nginx
      else
         echo -e "Error: Your procedure before reboot has been unsuccessfully and now you must start the script from the begining or contact author to help.\n"
         sleep 3
         rm /tmp/status_file.txt
         rm_service
         begin_prompt
      fi
   else
      begin_prompt
   fi
}

install_nginx() {
   rm_service
}

begin_prompt() {
   #=====================================START-HINT=========================================
   echo ""
   echo "--------------------------------------------------------------------------------"
   echo "-------------------- Rahgozar/Freedom repo Automated Script --------------------"
   echo "--------------------------------------------------------------------------------"
   echo ""
   echo "This is the an interactive-script for running x-ui xray service on a defined linux server. This script will run some utils and set few configs to proceed running x-ui. Script contains three main parts and you may encounter with REBOOTING machine during these parts that are listed below:"
   echo -e "\n"
   echo -e "1- Initializing Server for running Docker and other services with SSL Cert."
   echo -e "\n"
   echo -e "2- Running and configuring Nginx service to maintain ports and domains."
   echo -e "\n"
   echo -e "3- Installing x-ui service easily and automated and enjoy running it!"
   echo -e "\n"
   echo ""
   echo "--------------------------------------------------------------------------------"
   echo ""
   echo "First part will have 6 below sections going to do the procedure. At last of this part, your PC will reboot automatically and after that script re-runs automatically to continue procedure..."
   echo ""
   echo -e "\n"
   echo -e "1- Checking OS if any changes have been made to SSH default port and set it done (Recommanded)."
   echo -e "\n"
   echo -e "2- Updating mirrors and installing some necessary utils."
   echo -e "\n"
   echo -e "3- Installing Docker and Docker-compose to running multiple services easily (You will prompt to jump this section if you have already installed Docker)."
   echo -e "\n"
   echo -e "4- Getting SSL Cert for server with acme.sh."
   echo -e "\n"
   echo -e "+++++++++++++++| OPTIONALS |+++++++++++++++"
   echo -e "\n"
   echo -e "Optional 1- Firewall configurations."
   echo -e "Optional 2- Server optimizations."
   echo ""
   echo "--------------------------------------------------------------------------------"
   echo "--------------------------------------------------------------------------------"
   echo ""
   echo ""
   #=========================================================================================

   read -rsn1 -p "+++++Press any key to continue or ESC to exit..." key
      if [[ $key == $'\x1b' ]]; then
         echo -e "\n-----Exiting...\n"
         sleep 1
         exit 0
      else
         sleep 1
         sshd_change_check
      fi
}

status_file