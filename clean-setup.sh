#!/bin/bash

a2dissite webtrees.conf
a2ensite 000-default.conf
a2dismod rewrite
a2disconf allow-override.conf
systemctl reload apache2
rm /etc/apache2/sites-available/webtrees.conf
rm /etc/apache2/conf-available/allow-override.conf
rm -r backups backup.sh webtrees-install.log
rm -r /var/www/webtrees
mysql -e "DROP DATABASE webtrees"
mysql -e "DROP USER webtrees@localhost"
mysql -e "FLUSH PRIVILEGES"
systemctl restart mariadb