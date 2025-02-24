FROM debian:bookworm-slim

# 更新包列表并安装依赖
RUN apt update && apt upgrade -y

RUN apt install -y \
    locales \
    wget iproute2 openssh-server libgd-dev cmake make gcc g++ autoconf \
    libsodium-dev libonig-dev libssh2-1-dev libc-ares-dev libaio-dev sudo curl dos2unix \
    build-essential re2c cron bzip2 libzip-dev libc6-dev bison file rcconf flex vim m4 gawk less cpp binutils \
    diffutils unzip tar libbz2-dev libncurses5 libncurses5-dev libtool libevent-dev libssl-dev libsasl2-dev \
    libltdl-dev zlib1g-dev libglib2.0-0 libglib2.0-dev libkrb5-dev libpq-dev libpq5 gettext libcap-dev \
    libc-client2007e-dev psmisc patch git e2fsprogs libxslt1-dev xz-utils libgd3 libwebp-dev libvpx-dev \
    libfreetype6-dev libjpeg62-turbo libjpeg62-turbo-dev iptables libudev-dev libldap2-dev

RUN apt autoremove -y
RUN apt clean
RUN rm -rf /var/lib/apt/lists/* 

# 复制脚本
COPY ["bt.sh", "init_mysql.sh", "/"]
COPY ["phpmyadmin.sh", "/lnmp/"]

# 转换启动脚本
RUN dos2unix /bt.sh && dos2unix /init_mysql.sh

# 下载并安装宝塔面板及 lnmp 环境
RUN curl -sSO https://download.bt.cn/install/install_panel.sh \
    && echo y | bash install_panel.sh -P 8888 --ssl-disable

RUN btpip config set global.index-url https://mirrors.tencent.com/pypi/simple
RUN curl -o /lnmp/nginx.sh https://download.bt.cn/install/3/nginx.sh
RUN sh /lnmp/nginx.sh install 1.27
RUN curl -o /lnmp/php.sh https://download.bt.cn/install/4/php.sh
RUN sh /lnmp/php.sh install 8.3
RUN curl -o /lnmp/mysql.sh https://download.bt.cn/install/4/mysql.sh
RUN sh /lnmp/mysql.sh install 5.7
RUN sh /lnmp/phpmyadmin.sh install 5.2
RUN rm -rf /lnmp
RUN rm -rf /www/server/php/83/src
RUN rm -rf /www/server/mysql/mysql-test
RUN rm -rf /www/server/mysql/src.tar.gz
RUN rm -rf /www/server/mysql/src
RUN rm -rf /www/server/data/*
RUN rm -rf /www/server/nginx/src
RUN echo "docker_btlnmp_nas" > /www/server/panel/data/o.pl
RUN echo '["memuA", "memuAsite", "memuAdatabase", "memuAcontrol", "memuAfiles", "memuAlogs", "memuAxterm", "memuAcrontab", "memuAsoft", "memuAconfig", "dologin", "memu_btwaf", "memuAssl"]' > /www/server/panel/config/show_menu.json
RUN apt clean
RUN rm -rf /var/lib/apt/lists/*
RUN rm -rf /www/reserve_space.pl
RUN chmod +x /bt.sh
RUN chmod +x /init_mysql.sh
# 切换 Debian 镜像源为腾讯云源
RUN sed -i 's/deb.debian.org/mirrors.tencent.com/g' /etc/apt/sources.list.d/debian.sources
    

# 配置宝塔面板安全入口和用户名及密码，以及 SSH 密码
RUN echo btpanel | bt 6
RUN echo btpaneldocker | bt 5
RUN echo "/btpanel" > /www/server/panel/data/admin_path.pl
RUN echo "root:btpaneldocker" | chpasswd

# 打包宝塔面板，并清除www
RUN bt 2
RUN tar -zcf /www.tar.gz /www
RUN rm -rf /www

ENTRYPOINT ["/bin/sh","-c","/bt.sh"]

# 暴漏特定端口
EXPOSE 22 80 443 888 3306 8888

# 健康检查
HEALTHCHECK --interval=5s --timeout=3s CMD prot="http"; if [ -f "/www/server/panel/data/ssl.pl" ]; then prot="https"; fi; curl -k -i $prot://127.0.0.1:$(cat /www/server/panel/data/port.pl)$(cat /www/server/panel/data/admin_path.pl) | grep -E '(200|404)' || exit 1