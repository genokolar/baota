#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

public_file=/www/server/panel/install/public.sh
if [ ! -f $public_file ];then
	wget -O $public_file https://download.bt.cn/install/public.sh -T 5;
fi
. $public_file

download_Url=$NODE_URL
Root_Path=`cat /var/bt_setupPath.conf`
Setup_Path=$Root_Path/server/phpmyadmin
webserver=""



Install_phpMyAdmin()
{
	if [ -d "${Root_Path}/server/apache"  ];then
		webserver='apache'
	elif [ -d "${Root_Path}/server/nginx"  ];then
		webserver='nginx'
	elif [ -f "/usr/local/lsws/bin/lswsctrl" ];then
		webserver='openlitespeed'
	fi

	if [ "${webserver}" == "" ];then
		echo "No Web server installed!"
		exit 0;
	fi
	
    PHPVersion=""
	for phpVer in 52 53 54 55 56 70 71 72 73 74 80 81 82 83;
	do
		if [ -d "/www/server/php/${phpVer}/bin" ]; then
			PHPVersion=${phpVer}
		fi
	done
	
	if [ -z $PHPVersion ];then
	    echo "======================================"
	    echo "当前没有可用php，停止安装！"
	    echo "请先安装好php后再进行安装phpmyadmin！"
	    exit 1;
	fi
	
	wget -O phpMyAdmin.zip $download_Url/src/phpMyAdmin-${1}.zip -T20
	mkdir -p $Setup_Path

	unzip -o phpMyAdmin.zip -d $Setup_Path/ > /dev/null
	rm -f phpMyAdmin.zip
	rm -rf $Root_Path/server/phpmyadmin/phpmyadmin*
	
	
	phpmyadminExt=`cat /dev/urandom | head -n 32 | md5sum | head -c 16`;
	mv $Setup_Path/databaseAdmin $Setup_Path/phpmyadmin_$phpmyadminExt
	chmod -R 755 $Setup_Path/phpmyadmin_$phpmyadminExt
	chown -R www.www $Setup_Path/phpmyadmin_$phpmyadminExt
	chmod 755 /www/server/phpmyadmin
	
	secret=`cat /dev/urandom | head -n 32 | md5sum | head -c 32`;
	\cp -a -r $Setup_Path/phpmyadmin_$phpmyadminExt/config.sample.inc.php  $Setup_Path/phpmyadmin_$phpmyadminExt/config.inc.php
	sed -i "s#^\$cfg\['blowfish_secret'\].*#\$cfg\['blowfish_secret'\] = '${secret}';#" $Setup_Path/phpmyadmin_$phpmyadminExt/config.inc.php
	sed -i "s#^\$cfg\['blowfish_secret'\].*#\$cfg\['blowfish_secret'\] = '${secret}';#" $Setup_Path/phpmyadmin_$phpmyadminExt/libraries/config.default.php
	
	echo $1 > $Setup_Path/version.pl
	


	if [ "${webserver}" == "nginx" ];then
		sed -i "s#$Root_Path/wwwroot/default#$Root_Path/server/phpmyadmin#" $Root_Path/server/nginx/conf/nginx.conf
		rm -f $Root_Path/server/nginx/conf/enable-php.conf
		\cp $Root_Path/server/nginx/conf/enable-php-$PHPVersion.conf $Root_Path/server/nginx/conf/enable-php.conf
		sed -i "/pathinfo/d" $Root_Path/server/nginx/conf/enable-php.conf
		if [ ! -f "/www/server/nginx/conf/enable-php.conf" ];then
            touch /www/server/nginx/conf/enable-php.conf
		fi
		/etc/init.d/nginx reload
		
		PMA_PORT=$(cat $Root_Path/server/nginx/conf/nginx.conf|grep "listen "|grep -oE '[0-9]+')
	else
		sed -i "s#$Root_Path/wwwroot/default#$Root_Path/server/phpmyadmin#" $Root_Path/server/apache/conf/extra/httpd-vhosts.conf
		sed -i "0,/php-cgi/ s/php-cgi-\w*\.sock/php-cgi-${PHPVersion}.sock/" $Root_Path/server/apache/conf/extra/httpd-vhosts.conf
		/etc/init.d/httpd reload
		
		PMA_PORT=$(cat /www/server/apache/conf/extra/httpd-vhosts.conf |grep "Listen "|grep -oE '[0-9]+')
	fi
	
	echo ${PMA_PORT} > /www/server/phpmyadmin/port.pl
	
}

Uninstall_phpMyAdmin()
{
	rm -rf $Root_Path/server/phpmyadmin/phpmyadmin*
	rm -f $Root_Path/server/phpmyadmin/version.pl
	rm -f $Root_Path/server/phpmyadmin/version_check.pl
}

actionType=$1
version=$2

if [ "$actionType" == 'install' ];then
	Install_phpMyAdmin $version
elif [ "$actionType" == 'uninstall' ];then
	Uninstall_phpMyAdmin
fi
