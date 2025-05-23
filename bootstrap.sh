#!/bin/bash

# Fix dpkg if interrupted
dpkg --configure -a

# Update system
apt-get update
# apt-get upgrade -y

# Install required packages
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx php-fpm php-mysql php-xml php-gd php-curl php-mbstring php-zip mariadb-server wget curl ufw

# Install Adminer (lightweight phpMyAdmin alternative)
mkdir -p /var/www/adminer
wget -O /var/www/adminer/index.php https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php

# Install mkcert
curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
chmod +x mkcert-v*-linux-amd64
mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert

# Configure MariaDB
systemctl start mariadb
systemctl enable mariadb

# Secure MariaDB installation (automated)
mysql -e "UPDATE mysql.user SET Password = PASSWORD('root') WHERE User = 'root'"
mysql -e "DROP DATABASE IF EXISTS test"
mysql -e "DELETE FROM mysql.user WHERE User = ''"
mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -e "FLUSH PRIVILEGES"

# Create WordPress database
mysql -u root -proot -e "CREATE DATABASE wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -proot -e "CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'wppass';"
mysql -u root -proot -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';"
mysql -u root -proot -e "FLUSH PRIVILEGES;"

# Configure PHP-FPM
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
cp /vagrant/conf/php.ini /etc/php/$PHP_VERSION/fpm/conf.d/99-wordpress.ini

# Configure Nginx
rm -f /etc/nginx/sites-enabled/default
ln -sf /vagrant/conf/wordpress.conf /etc/nginx/sites-enabled/

# Set permissions
mkdir -p /var/www
ln -sf /vagrant/app/wordpress /var/www/wordpress

# Configure WordPress
cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php
sed -i "s/database_name_here/wordpress/" /var/www/wordpress/wp-config.php
sed -i "s/username_here/wpuser/" /var/www/wordpress/wp-config.php
sed -i "s/password_here/wppass/" /var/www/wordpress/wp-config.php
sed -i "s/localhost/localhost/" /var/www/wordpress/wp-config.php

chown -R www-data:www-data /var/www
chmod -R 755 /var/www

# Configure UFW
ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable

# Generate SSL certificates first
mkcert -install
cd /root
mkcert localhost example.com 127.0.0.1 ::1

# Move certificates to expected location
mkdir -p /root/.local/share/mkcert/
mv /root/localhost+3.pem /root/.local/share/mkcert/
mv /root/localhost+3-key.pem /root/.local/share/mkcert/

# Start services
systemctl restart php$PHP_VERSION-fpm
systemctl restart nginx
systemctl enable nginx
systemctl enable php$PHP_VERSION-fpm

echo "WordPress stack installation completed!"
echo "Optional: Add to /etc/hosts: 127.0.0.1 example.com"
echo "Visit: http://localhost:8080 or http://example.com:8080"
echo "HTTPS: https://localhost:8443 or https://example.com:8443"
echo "Adminer: http://localhost:8080/adminer"
echo "Database: wordpress | User: wpuser | Password: wppass"