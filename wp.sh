#!/bin/bash 
# 
# <UDF name="ssuser" Label="New User" example="Account to login to your Linode" />
# <UDF name="sspassword" Label="New User Password" example="Password for the account" />
# <UDF name="hostname" Label="Hostname" example="Local hostname for your Linode" />
# <UDF name="website" Label="Website FQDN" example="Domain for your Linode: example.com" />
# <UDF name="db_password" Label="MySQL root Password" example="Root password for MySQL for WordPress nstall" />
# <UDF name="dbuser" Label="MySQL Username" example="Username for WordPress in MySQL" />
# <UDF name="dbuser_password" Label="MySQL User Password" example="Password for WordPress MySQL user" />
#
# Version control: https://github.com/tkulick/stackscripts/
#

# add sudo user
adduser $SSUSER --disabled-password --gecos "" && \
echo "$SSUSER:$SSPASSWORD" | chpasswd
adduser $SSUSER sudo

# updates
apt-get -o Acquire::ForceIPv4=true update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
apt-get -o Acquire::ForceIPv4=true update -y

#SET HOSTNAME   
hostnamectl set-hostname $HOSTNAME
echo "127.0.0.1   $HOSTNAME" >> /etc/hosts

#INSTALL APACHE
apt-get install apache2 -y

# edit apache config
sed -ie "s/KeepAlive Off/KeepAlive On/g" /etc/apache2/apache2.conf

#Create a copy of the default Apache configuration file for your site:
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$WEBSITE.conf

# configuration of vhost file
cat <<END >/etc/apache2/sites-available/$WEBSITE.conf
<Directory /var/www/html/$WEBSITE/public_html>
    Require all granted
</Directory>
<VirtualHost *:80>
        ServerName $WEBSITE
        ServerAlias www.$WEBSITE
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html/$WEBSITE/public_html

        ErrorLog /var/www/html/$WEBSITE/logs/error.log
        CustomLog /var/www/html/$WEBSITE/logs/access.log combined

</VirtualHost>
END

# Make public_html & logs
mkdir -p /var/www/html/$WEBSITE/{public_html,logs,src}

# Remove default apache page
rm /var/www/html/index.html

# Install wordpress
cd /var/www/html/$WEBSITE/src/
sudo chown -R www-data:www-data /var/www/html/$WEBSITE/
sudo wget http://wordpress.org/latest.tar.gz
sudo -u www-data tar -xvf latest.tar.gz
sudo mv latest.tar.gz wordpress-`date "+%Y-%m-%d"`.tar.gz
sudo mv wordpress/* ../public_html/
sudo chown -R www-data:www-data /var/www/html/$WEBSITE/public_html

#Link your virtual host file from the sites-available directory to the sites-enabled directory:
sudo a2ensite $WEBSITE.conf

#Disable the default virtual host to minimize security risks:
a2dissite 000-default.conf

# restart apache
systemctl reload apache2
systemctl restart apache2


# Install MySQL Server in a Non-Interactive mode. Default root password will be "root"
echo "mysql-server mysql-server/root_password password $DB_PASSWORD" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DB_PASSWORD" | sudo debconf-set-selections
apt-get -y install mysql-server

mysql -uroot -p$DB_PASSWORD -e "create database wordpress"
mysql -uroot -p$DB_PASSWORD -e "CREATE USER '$DBUSER' IDENTIFIED BY '$DBUSER_PASSWORD';
mysql -uroot -p$DB_PASSWORD -e "GRANT ALL PRIVILEGES ON wordpress.* TO '$DBUSER';"

service mysql restart

#installing php
apt-get install php7.0 php-pear libapache2-mod-php7.0 php7.0-mysql -y php-gd

# making directory for php? giving apache permissions to that log? restarting php
mkdir /var/log/php
chown www-data /var/log/php
systemctl restart apache2
