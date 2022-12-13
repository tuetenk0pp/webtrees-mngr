#!/bin/bash

# https://intoli.com/blog/exit-on-errors-in-bash-scripts/
# exit when any command fails
set -e
# keep track of the last executed command
trap 'LAST_COMMAND=$CURRENT_COMMAND; CURRENT_COMMAND=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'E_CODE=$?; [ ! $E_CODE -eq 0 ] && echo "\"${LAST_COMMAND}\" command filed with exit code $E_CODE. Aborting script."' EXIT

# start with script
echo "This is an interactive install-script for webtrees."
echo "It is meant for non-technical users who want to get a Webtrees installation up quickly."
echo "The script needs a fresh ubuntu-server install to run on."
echo "Do not continue if you already have a webserver and some sort of webapp installed!"
echo "Please submit any issues here https://github.com/Tuetenk0pp/webtrees-mngr/issues/."
echo "Would you like to continue with the installation?"
select yn in "Yes" "No"; do
        case $yn in
                Yes ) echo "Ok let's go"; break;;
                No ) echo "Install-script aborted"; exit 0;;
        esac
done
# Ask for user input and set variables
read -p "Please enter Base URL without leading 'http://': " BASEURL
echo "Would you like to provision an SSL certificate? Select 'No' if you plan to host behind a reverse proxy."
select yn in "Yes" "No"; do
        case $yn in
                Yes ) read -p "Please enter a valid e-mail address for letsencrypt notifications: " EMAIL; CERTBOT=TRUE; break;;
                No ) CERTBOT=FALSE; break;;
        esac
done
echo "Would you like to enable pretty URLs? (recommended)"
select yn in "Yes" "No"; do
        case $yn in
                Yes ) PRETTY_URLS=TRUE; break;;
                No ) PRETTY_URLS=FALSE; break;;
        esac
done
echo "Would you like to increase the upload limit to 30 Megabytes? (recommended)"
select yn in "Yes" "No" "Custom"; do
        case $yn in
                Yes ) PHP_POST_MAX_SIZE=31M; PHP_UPLOAD_MAX_FILESIZE=30M; break;;
                No ) break;;
                Custom ) read -p "PHP_POST_MAX_SIZE: " PHP_POST_MAX_SIZE; read -p "PHP_UPLOAD_MAX_FILESIZE: " PHP_UPLODAD_MAX_FILESIZE; break;;
        esac
done
PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE:-8M}
PHP_UPLOAD_MAX_FILESIZE=${PHP_UPLOAD_MAX_FILESIZE:-2M}
read -p "Enter Database User [press enter for default: webtrees]: " DB_USER
DB_USER=${DB_USER:-webtrees}
read -p "Enter Database Name [press enter for default: webtrees]: " DB_NAME
DB_NAME=${DB_NAME:-webtrees}
read -p "Enter Databse Password: " DB_PASSWORD
read -p "Enter Table Prefix [press enter for default: wt_]:" DB_PREFIX
DB_PREFIX=${DB_PREFIX:-wt_}

# Display the set variables and ask for confirmation
echo "This is the config:"
echo "Base URL:                         $BASEURL"
echo "Provision SSL certificate:        $CERTBOT"
[ "$CERTBOT" = "TRUE" ] && echo "Email:                            $EMAIL"
# if [ $CERTBOT = TRUE ]
# then
#         echo "Email:                            $EMAIL"
# fi
echo "Pretty URLs:                      $PRETTY_URLS"
echo "Post Max Size:                    $PHP_POST_MAX_SIZE"
echo "Upload Max Filesize:              $PHP_UPLOAD_MAX_FILESIZE"
echo "Database Name:                    $DB_NAME"
echo "Database User:                    $DB_USER"
echo "Database Password:                $DB_PASSWORD"
echo "Table Prefix:                     $DB_PREFIX"
echo "Would you like to continue with this config?"
select yn in "Yes" "Restart"; do
        case $yn in
                Yes ) break;;
                Restart ) break;;
        esac
done

# Install necessary software
echo "I will now install and configure the following software:"
echo "uncomplicated firewall, apache webserver, mariadb, php, webtrees, unzip"
echo "Would you like to upgrade all system packages as well? Recommended, but this might take some time."
APT_PACKAGES="ufw apache2 mariadb-server php libapache2-mod-php php-apcu php-curl php-gd php-intl php-json php-mbstring php-mysql php-xml php-zip unzip"
select yn in "Yes" "No"; do
        case $yn in
                Yes ) apt-get update >> /dev/null && apt upgrade -y >> /dev/null && apt-get install $APT_PACKAGES -y >> /dev/null; break;;
                No ) apt-get update >> /dev/null && apt-get install $APT_PACKAGES -y >> /dev/null; break;;
        esac
done
[ "$CERTBOT" = "TRUE" ] && echo "Installing certbot" && apt-get install certbot python3-certbot-apache -y

# Set the machine Hostname
echo "Setting hostname"
echo "Maybe don't do this"
HOSTNAME=$(</etc/hostname)
sed -i "s/$HOSTNAME/$BASEURL/" /etc/hostname 

# Set up apache
echo "Setting up Webserver"
# Download latest Release https://gist.github.com/steinwaywhw/a4cd19cda655b8249d908261a62687f8
echo "Download latest Webtrees Release"
curl -s https://api.github.com/repos/fisharebest/webtrees/releases/latest | grep "browser_download_url.*zip" | cut -d : -f 2,3 | tr -d \" | wget -qi -
unzip -qq webtrees-*.zip
rm -r webtrees-*.zip
A2_ROOT=/var/www/webtrees
echo "Moving files in place"
mv webtrees $A2_ROOT
chown -R www-data:www-data $A2_ROOT
echo "Set up virtual host"
A2_VHOST=/etc/apache2/sites-available/webtrees.conf
touch $A2_VHOST
echo "<VirtualHost *:80>" >> $A2_VHOST
echo "  ServerName $BASEURL" >> $A2_VHOST
echo "  DocumentRoot $A2_ROOT" >> $A2_VHOST
echo "  ErrorLog ${APACHE_LOG_DIR}/error.log" >> $A2_VHOST
echo "  CustomLog ${APACHE_LOG_DIR}/access.log combined" >> $A2_VHOST
echo "</VirtualHost>" >> $A2_VHOST
a2ensite webtrees.conf >> /dev/null
a2dissite 000-default.conf
apache2ctl configtest && systemctl reload apache2

# Set up mariadb
echo "Setting up database"
# mysql_secure_installation https://stackoverflow.com/a/27759061/20733074
echo "Kill the anonymous users"
mysql -e "DROP USER IF EXISTS ''@'localhost'"
# Because our hostname varies we'll use some Bash magic here.
mysql -e "DROP USER IF EXISTS ''@'$(hostname)'"
echo "Kill off the demo database"
mysql -e "DROP DATABASE IF EXISTS test"
echo "Create Webtrees database"
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME"
echo "Create Webtrees user"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD'"
echo "Make our changes take effect"
mysql -e "FLUSH PRIVILEGES"

# Set up php
echo "Setting up php"
# Find current php version https://unix.stackexchange.com/q/566884
PHP_CURRENT_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_CONFIG_FILE=/etc/php/$PHP_CURRENT_VERSION/apache2/php.ini
# Write settings to config file https://github.com/H2CK/webtrees/blob/webtrees-2.1/08_set_php.sh
sed -i -r 's,upload_max_filesize[ ]*=[ ]*[a-zA-Z0-9:\/\.]*,upload_max_filesize = '"$PHP_UPLOAD_MAX_FILESIZE"',g' "$PHP_CONFIG_FILE"
sed -i -r 's,post_max_size[ ]*=[ ]*[a-zA-Z0-9:\/\.]*,post_max_size = '"$PHP_POST_MAX_SIZE"',g' "$PHP_CONFIG_FILE"

# Set up ufw
echo "Setting up firewall"
ufw allow "OpenSSH" >> /dev/null
ufw allow "Apache Full" >> /dev/null
ufw --force enable

# Provision SSL certificates
if [ "$CERTBOT" = "TRUE" ]
then
        echo "Provisioning SSL certificate"
        certbot --apache -d $BASEURL -n --agree-tos -m $EMAIL --redirect
        echo "Setting up automatic certificate renewal"
        systemctl enable certbot.timer
        echo "Testing renewal process"
        certbot renew --dry-run
fi

# Webtrees final
[ "$CERTBOT" = "TRUE" ] && echo "Done. Visit https://$BASEURL/ in your webbrowser and complete the setup." || echo "Done. Visit http://$BASEURL/ in your webbrowser and complete the setup."
echo "Here is the required information:"
echo "Database Type:                    MySQL"
echo "Server Name:                      localhost"
echo "Port Number:                      3306"
echo "Database User:                    $DB_USER"
echo "Database Password:                $DB_PASSWORD"
echo "Database Name:                    $DB_NAME"
echo "Table Prefix:                     $DB_PREFIX"
read -p "Once you are done, press Enter to continue."
echo "Setting pretty URLs"
WT_CONFIG=$A2_ROOT/data/config.ini.php
if [ "$PRETTY_URLS" = "TRUE" ]
then
        # allow rewrites in the /var/www directory
        A2_ALLOWOVERRIDE=/etc/apache2/conf-available/allow-override.conf
        touch $A2_ALLOWOVERRIDE
        echo "<Directory $A2_ROOT>" >> $A2_ALLOWOVERRIDE
        echo "        Options Indexes FollowSymLinks" >> $A2_ALLOWOVERRIDE
        echo "        AllowOverride All" >> $A2_ALLOWOVERRIDE
        echo "        Require all granted" >> $A2_ALLOWOVERRIDE
        echo "</Directory>" >> $A2_ALLOWOVERRIDE
        a2enconf allow-override.conf >> /dev/null
        a2enmod rewrite >> /dev/null
        # generate .htaccess file
        HTACCESS=$A2_ROOT/.htaccess
        touch $HTACCESS
        echo "<IfModule mod_rewrite.c>" >> $HTACCESS
        echo "        RewriteEngine On" >> $HTACCESS
        echo "        RewriteBase /" >> $HTACCESS
        echo "        # GIT config files can contain credentials or other sensitive data." >> $HTACCESS
        echo "        RewriteRule \.git - [F]" >> $HTACCESS
        echo "        # User data is stored here by default." >> $HTACCESS
        echo "        RewriteRule ^data(/|$) - [F]" >> $HTACCESS
        echo "        # Nothing sensitive here, but there is no need to publish it." >> $HTACCESS
        echo "        RewriteRule ^app(/|$) - [F]" >> $HTACCESS
        echo "        RewriteRule ^modules - [F]" >> $HTACCESS
        echo "        RewriteRule ^resources(/|$) - [F]" >> $HTACCESS
        echo "        RewriteRule ^vendor(/|$) - [F]" >> $HTACCESS
        echo "        RewriteCond %{REQUEST_FILENAME} !-d" >> $HTACCESS
        echo "        RewriteCond %{REQUEST_FILENAME} !-f" >> $HTACCESS
        echo "        RewriteRule ^ index.php [L]" >> $HTACCESS
        echo "</IfModule>" >> $HTACCESS
        chown www-data:www-data $HTACCESS
        # change webtrees config
        sed -i -r 's,rewrite_urls=\"0\",rewrite_urls=\"1\",g' $WT_CONFIG
        # restart apache
        systemctl restart apache2
fi

# Set up backup
echo "Would you like to use the included backup script to regulary make backups of your Database and Webroot folder?"
echo "The script uses borgbackup to create incremental backups locally."
echo "If you wish to also sync backups to a remote location, I recommend you checkout rclone."
select yn in "Yes" "No"; do
        case $yn in
                Yes )
                        echo "Alright, I will configure borgbackup now"
                        echo "Installing borg"
                        apt-get install borgbackup -y >> /dev/null
                        echo "Initializing backup repository"
                        borg init --encryption=none ./backups && echo "All backups will go here: $(pwd)/backups/" && echo "Note: borg wil run under root permissions"
                        borg config ./backups additional_free_space 1G
                        echo "Setting up backup script"
                        cp backup.sh.sample backup.sh
                        sed -i -r 's,export BORG_REPO,export BORG_REPO='"$(pwd)"'/backups/,g' ./backup.sh
                        chmod +x ./backup.sh
                        crontab -l | { echo "0 */12 * * * $(pwd)/backup.sh"; } | crontab - && echo "Crontab for root user installed"
                        echo "Running first backup"
                        ./backup.sh && echo "First backup done"
                        break;;
                No ) echo "Alright, no backups"; break;;
        esac
done
echo "Thank you for using this script."
