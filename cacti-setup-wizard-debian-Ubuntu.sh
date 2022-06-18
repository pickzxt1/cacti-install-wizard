#!/bin/bash

##By ： AoaBo's


echo "这个脚本需要 git"
apt-get install git  -y



echo "此脚本将下载所有 Cacti 依赖项并从 cacti github 下载所选的 cacti 版本"
echo "版权所有 cacti @ cacti.net!"


function new_install () {


#Download chosen release

echo "这是一些当前的 cacti 发行版本 \n"
 git ls-remote --tags https://github.com/Cacti/cacti|grep 'release/[[:digit:]\.]*$'|tail -10|awk '{print $2}'|tr 'refs/tags/release' ' '|sed 's/^ *//;s/ *$//'


###One day I will have this auto populate 


echo  "您想下载哪个版本？点击进入最新"
read version

if  [ "$version" == "" ]
then
git clone -b 1.2.x https://github.com/Cacti/cacti.git


else 
wget https://github.com/Cacti/cacti/archive/release/$version.tar.gz
tar -xvf $version.tar.gz 
mv cacti-release-$version cacti
fi

##Download required packages for cacti

echo "cacti requires a LAMP stack as well as some required plugins we will now install the required packages"
apt-get update
apt-get  install -y apache2 libapache2-mod-php  rrdtool mariadb-server snmp snmpd php php-mysql  libapache2-mod-php   php-snmp php-xml php-mbstring php-json php-gd php-gmp php-zip php-ldap 




echo "是否安装脊椎轮询器 输入 1 表示是 2 表示否"
read answer
if [ $answer == "1" ]
then
##Download packages needed for spine
apt-get  install -y build-essential dos2unix dh-autoreconf libtool  help2man libssl-dev libmysql++-dev  librrds-perl libsnmp-dev 
echo "下载和编译脊椎"
git clone https://github.com/Cacti/spine.git
cd spine
./bootstrap
./configure
make
make install
chown root:root /usr/local/spine/bin/spine
chmod u+s /usr/local/spine/bin/spine
cd ..

else
echo "不会安装脊椎依赖项"
fi                                                       


###Find installed version of PHP

php_version="$(php -v | head -n 1 | cut -d " "  -f 2 | cut -f1-2 -d".")"



##Timezone settings needed for cacti
echo "Enter your PHP time zone i.e America/Toronto  Default is US/Central "
read timezone
if [ $timezone = "" ] 
then

echo "date.timezone =" US/Central  >> /etc/php/$php_version/cli/php.ini 
echo "date.timezone =" US/Central >> /etc/php/$php_version/apache2/php.ini

else


echo "date.timezone =" $timezone >> /etc/php/$php_version/cli/php.ini 
echo "date.timezone =" $timezone >> /etc/php/$php_version/apache2/php.ini

fi 
#move cacti install to chosen  directory


echo "您想在哪里安装 cacti 默认位置是 /var/www/html 输入默认位置"
read location
if [$location = ""]
then

location="/var/www/html"

mv cacti /var/www/html
else
mv cacti $location
fi


#Create cacti user and change permission of directory
echo "您想在哪个用户下运行 Cacti（默认为 www-data）按回车键默认"
read user
if [$user = ""]
then 
user="www-data"
echo  "仙人掌将在 $user"
chown -R  $user:$user $location/cacti
else 
useradd $user
chown -R $user:$user $location/cacti
###Create cron entry for new user 

fi

##Create  cron entry 
touch /etc/cron.d/$user
echo "*/5 * * * * $user php $location/cacti/poller.php > /dev/null 2>&1" > /etc/cron.d/$user 



#assign permissions for cacti installation to www-data user
chown -R www-data:www-data $location/cacti/resource/snmp_queries/          
chown -R www-data:www-data $location/cacti/resource/script_server/
chown -R www-data:www-data $location/cacti/resource/script_queries/
chown -R www-data:www-data $location/cacti/scripts/
chown -R www-data:www-data $location/cacti/cache/boost/
chown -R www-data:www-data $location/cacti/cache/mibcache/
chown -R www-data:www-data $location/cacti/cache/realtime/
chown -R www-data:www-data $location/cacti/cache/spikekill/
touch $location/cacti/log/cacti.log
chmod 664 $location/cacti/log/cacti.log
chown -R www-data:www-data  $location/cacti/log/
cp $location/cacti/include/config.php.dist $location/cacti/include/config.php





##Adding Maria DB conf  
echo "innodb_flush_log_at_timeout = 4" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_read_io_threads = 34"   >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_write_io_threads = 17" >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo "max_heap_table_size = 70M"    >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "tmp_table_size = 70M"         >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "join_buffer_size = 130M" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_buffer_pool_size = 250M" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_io_capacity = 5000" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_io_capacity_max = 10000" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_file_format = Barracuda" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_large_prefix = 1" >>  /etc/mysql/mariadb.conf.d/50-server.cnf


systemctl restart mysql



##Create database 
echo "您想自定义数据库名称和用户吗？按回车键获取默认值"
read customize

if [[ $customize = "" ]] 
then

password="$(openssl rand -base64 32)"

mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE cacti DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ;
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti'@'localhost' IDENTIFIED BY '$password'; ;
GRANT SELECT ON mysql.time_zone_name TO cacti@localhost;
USE mysql;
ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

#pre populate cacti db
mysql -u root  cacti < $location/cacti/cacti.sql
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root  mysql

sed -i -e 's@^$database_type.*@$database_type = "mysql";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_default.*@$database_default = "cacti";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_hostname.*@$database_hostname = "127.0.0.1";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_username.*@$database_username = "cacti";@g' /var/www/html/cacti/include/config.php
##sed -i -e 's@^$database_password.*@$database_password = "cacti";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_password.*@$database_password = "'$password'";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_port.*@$database_port = "3306";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_ssl.*@$database_ssl = "false";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^//$url_path@$url_path@g' /var/www/html/cacti/include/config.php






echo "
具有以下详细信息的默认数据库设置
数据库名称 cacti
数据库用户名 cacti
数据库密码 $password
"





else

echo "输入数据库名称"
read customdbname
echo "输入数据库用户"
read customdbuser
echo "输入数据库密码"
read customdbpassword



mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE $customdbname;
GRANT ALL PRIVILEGES ON $customdbname.* TO '$customdbuser'@'localhost' IDENTIFIED BY '$customdbpassword';
GRANT SELECT ON mysql.time_zone_name TO $customdbuser@localhost;
ALTER DATABASE $customdbname CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "Pre-populating cacti DB"
mysql -u root  $customdbname < $location/cacti/cacti.sql
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root  mysql





sed -i -e 's@^$database_type.*@$database_type = "mysql";@g' $location/cacti/include/config.php
sed -i -e 's@^$database_default.*@$database_default = '$customdbname'\;@g' $location/cacti/include/config.php
sed -i -e 's@^$database_hostname.*@$database_hostname = "127.0.0.1";@g' $location/cacti/include/config.php
sed -i -e 's@^$database_username.*@$database_username = '$customdbuser';@g' $location/cacti/include/config.php
sed -i -e 's@^$database_password.*@$database_password = '$customdbpassword';@g' $location/cacti/include/config.php
sed -i -e 's@^$database_port.*@$database_port = "3306";@g' "$location"/cacti/include/config.php
sed -i -e 's@^$database_ssl.*@$database_ssl = "false";@g' "$location"/cacti/include/config.php
sed -i -e 's@^//$url_path@$url_path@g' $location/cacti/include/config.php







fi



###Adding recomended PHP settings 
sed -e 's/max_execution_time = 30/max_execution_time = 60/' -i /etc/php/$php_version/apache2/php.ini
sed -e 's/memory_limit = 128M/memory_limit = 400M/' -i /etc/php/$php_version/apache2/php.ini




echo "这个脚本可以从 cacti 组下载以下插件 monitor,thold,audit 你想安装它们吗？输入yes下载 回车跳过"
read plugins
 if [[  $plugins == "yes"  ]]
  then
   git clone https://github.com/Cacti/plugin_thold.git  thold
    git clone https://github.com/Cacti/plugin_monitor.git monitor
    git clone https://github.com/Cacti/plugin_audit.git audit


   chown -R $user:$user thold
    chown -R $user:$user monitor
     chown -R $user:$user audit
     mv thold $location/cacti/plugins
      mv monitor $location/cacti/plugins
       mv monitor $location/cacti/plugins




else
 echo "不会安装插件"
  fi



echo "您想下载我的 RRD 监控脚本吗？输入yes下载 回车跳过 "
read mon_script
if [[ $mon_script == "yes" ]]
  then
  git clone  https://github.com/bmfmancini/rrd-monitor.git
      else
       echo "不会下载脚本"
fi

####Create cron for cacti user

touch /etc/cron.d/$user
echo "*/5 * * * * $user php $location/cacti/poller.php > /dev/null 2>&1" > /etc/cron.d/$user 








echo "启动 Mysqldb 和 Apache 服务器以进行服务刷新"
systemctl restart mysql
systemctl restart apache2





echo "设置已完成，您现在可以通过 CLI 安装 cacti 或访问 websetup 以继续通过 CLI 安装类型是，如果失败，请通过 Web 控制台完成"
read installanswer
if [[  $installanswer == "yes" ]]
then 
php $location/cacti/cli/install_cacti.php --accept-eula --install -d
else 
echo "请在 Web 控制台上完成安装"
fi




}



function spine_install () {


##Download packages needed for spine
apt-get  install -y build-essential dos2unix dh-autoreconf libtool  help2man libssl-dev     librrds-perl libsnmp-dev 
apt-get install -y libmysql++-dev ##For debian 9 and below
apt-get install -y default-libmysqlclient-dev ###For debian 10+

echo " 您想使用哪个版本的脊椎？点击回车获取最新版本或输入发布版本，即 1.2.3 通常应该与您安装的 Cacti 版本匹配"
read version

if [$version = ""]
then

echo "下载最新版本的脊椎并编译 "
git clone https://github.com/Cacti/spine.git spine
cd spine
./bootstrap
./configure
make
make install
chown root:root /usr/local/spine/bin/spine
chmod u+s /usr/local/spine/bin/spine

else

wget https://github.com/Cacti/spine/archive/release/$version.zip
unzip $version.zip
cd spine-release-$version
./bootstrap
./configure
make
make install
chown root:root /usr/local/spine/bin/spine
chmod u+s /usr/local/spine/bin/spine

fi

cp /usr/local/spine/etc/spine.conf.dist  /usr/local/spine/etc/spine.conf



echo "Spine 已经编译和安装，您现在需要在 /usr/local/spine/etc/spine.conf 配置你的信息"

echo "您想配置您的 spin.conf 文件吗？y或n"
read answer
if [ $answer == "y" ]
then
echo "输入数据库用户名"
read user
echo "输入数据库密码"
read password
echo "输入数据库名称"
read databasename

sed -i -e 's@^DB_Host.*@DB_Host  127.0.0.1@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_User.*@DB_User  '$user'@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_Pass.*@DB_Pass  '$password'@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_Database.*@DB_Database  '$databasename'@g' /usr/local/spine/etc/spine.conf

else


echo "脊柱安装完成"

fi

}


function cacti_upgrade () {

echo "停止 cron 服务"
systemctl stop cron


echo "此选项将升级您现有的仙人掌安装
您需要提供数据库信息和仙人掌安装路径"

echo "指定您的数据库用户名"
read currentdbuser

echo "指定您的数据库名称"
read currentdb
echo "指定您当前的数据库密码"
read currentdbpwd
echo "指定您的仙人掌安装路径，通常 /var/www/html 按回车默认"
read currentpath
if [  "$currentpath" == "" ]
then 
currentpath="/var/www/html"
fi
echo "指定备份仙人掌文件的备份路径默认为 /tmp"
read backpath
if [  "$backpath" == "" ]
then
backpath="/tmp"
fi

echo "备份数据库"
mysqldump -u $currentdbuser -p $currentdbpassword   $currentdb > cacti_db_backup.sql



echo  "您想升级到哪个版本？"
read version

if  [ "$version" == "" ]
then
git clone https://github.com/Cacti/cacti.git


else 
wget https://github.com/Cacti/cacti/archive/release/$version.zip
unzip $version 
mv cacti-release-$version cacti
fi


mv $currentpath/cacti  $backpath
mv cacti $currentpath

echo "将旧的 config.php 文件添加到新的 cacti 文件夹中"
cp $backpath/cacti/include/config.php $currentpath/cacti/include/config.php

echo "将插件文件移回新的仙人掌文件夹r"
cp -R $backpath/cacti/plugins/* $currentpath/cacti/plugins/



echo "您以什么系统用户身份运行cacti？ www-data为默认"
read cactiuser
if [ "$cactiuser" == "" ]
then 
cactiuser="www-data"

fi
chown -R $cactiuser:$cactiuser $currentpath/cacti



echo "仙人掌已升级为" + $version
echo " 已对您以前的版本进行了备份 " $backpath
echo "确认一切正常后" $backpath




systemctl start cron

}





#####Menu 




choice='Select a operation: '
options=("全新安装" "只安装脊柱" "升级仙人掌" "退出")
select opt in "${options[@]}"
do
    case $opt in
        "全新安装")
            new_install
            ;;
        "只安装脊柱")
            spine_install
            ;;
        "升级仙人掌")
            cacti_upgrade
            ;;
        "退出")
            break
            ;;
        *) echo invalid option;;
    esac
done

