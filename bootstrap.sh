#!/usr/bin/env bash
DBNAME=judodb
DBUSER=basejudo
DBPASSWD=test123

case $(id -u) in
    0) 
        echo "mysql-server mysql-server/root_password password $DBPASSWD" | debconf-set-selections
        echo "mysql-server mysql-server/root_password_again password $DBPASSWD" | debconf-set-selections
        apt-get update
        apt-get install -y apache2 libapache2-mod-php5 mysql-server mysql-client drush php5-gd php5-curl php5-dev make php-fpdf git unzip maven
        apt-get install -y ant openjdk-7-jdk
        adduser vagrant www-data
        adduser vagrant adm
        #pecl install uploadprogress
        #echo -e "extension=uploadprogress.so" > /etc/php5/conf.d/uploadprogress.ini
        a2enmod expires; a2enmod rewrite
        sed -i '/^;default_charset/s|.*|default_charset = "UTF-8"|' /etc/php5/apache2/php.ini
        sed -i '/^Listen 80/s|.*|Listen 8080|' /etc/apache2/ports.conf
        cat > /etc/apache2/sites-available/default.conf <<"EOF"
<VirtualHost *:8080>
        ServerAdmin webmaster@localhost

        DocumentRoot /var/www
        <Directory />
                Options FollowSymLinks
                AllowOverride None
                deny from all
        </Directory>
        <Directory /var/www/frontend>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride None
                Order allow,deny
                allow from all
        </Directory>
        <Directory /var/www/backend>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride None
                Order allow,deny
                allow from all
        </Directory>

        <Directorymatch "^/.*/\.git+/">
                Order deny,allow
                Deny from all
        </Directorymatch>
        <Files ~ "^\.git">
                Order allow,deny
                Deny from all
        </Files>

        RewriteEngine On
        RewriteRule ^/backend/(.*)$ /backend/$1 [L]
        RewriteRule ^(.*)$ /frontend/$1

        ErrorLog ${APACHE_LOG_DIR}/error.log

        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn

        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
        a2ensite default
        a2dissite 000-default
        service apache2 restart
        sudo -u vagrant -i $0
        ;;
    *)
        if [ ! -d JudoDB ]; then
            git clone https://github.com/patricklam/JudoDB.git
        fi
        if [ ! -d judodb-backend ]; then
            git clone https://github.com/patricklam/judodb-backend.git
            mysql -uroot -p$DBPASSWD < judodb-backend/db.sql
            mysql -uroot -p$DBPASSWD -e "CREATE USER $DBUSER"
            mysql -uroot -p$DBPASSWD -e "GRANT ALL PRIVILEGES ON $DBNAME.* TO '$DBUSER'@'localhost' identified by '$DBPASSWD'"
            mysql -uroot -p$DBPASSWD -e "CREATE DATABASE IF NOT EXISTS $DBNAME"
            mysql -uroot -p$DBPASSWD $DBNAME < judodb-backend/db.sql
            cat > judodb-backend/_dbconfig.php <<EOF
<?php
// Customize this file to point to the database where db.sql has been setup.

\$DBI_DATABASE="$DBNAME";
\$DBI_USERNAME="$DBUSER";
\$DBI_PASSWORD="$DBPASSWD";
\$DBI_HOST="localhost";
?>
EOF
        fi

        sudo rm -rf /var/www/html
        sudo ln -s /home/vagrant/judodb-backend /var/www/backend

        if [ ! -d tools ]; then
            mkdir -p tools
            if [ ! -f tools/gwt-2.7.0.zip ]; then
                cd ~/tools
                wget http://storage.googleapis.com/gwt-releases/gwt-2.7.0.zip
                unzip gwt-2.7.0.zip
            fi
	    if [ ! -f ~/tools/gwtbootstrap3 ]; then
		cd ~/tools
                git clone https://github.com/gwtbootstrap3/gwtbootstrap3
		cd gwtbootstrap3
		mvn package
		cp gwtbootstrap3/target/gwtbootstrap3-1.0-SNAPSHOT.jar ~/tools
            fi
	    if [ ! -f ~/tools/gwtbootstrap3-extra ]; then
		cd ~/tools
		git clone https://github.com/gwtbootstrap3/gwtbootstrap3-extras
		cd gwtbootstrap3-extras
		mvn package
		cp target/gwtbootstrap3-extras-1.0-SNAPSHOT.jar ~/tools
	    fi
        fi

        mkdir -p ~/bin
	if [ ! -f ~/bin/compile ]; then
	    cat > ~/bin/compile <<EOF
ant
sudo cp -a /home/vagrant/JudoDB/war/* /var/www/frontend
EOF
	    chmod +x ~/bin/compile
	fi

        cd ~/JudoDB
	~/bin/compile

        if [ ! -d /var/www/frontend ]; then
            sudo mkdir /var/www/frontend
            sudo cp -a /home/vagrant/JudoDB/war/* /var/www/frontend
            sudo cp /var/www/frontend/_config_template.php /var/www/frontend/_config.php
        fi

        ;;
esac
