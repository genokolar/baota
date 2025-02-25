#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_path=/etc/init.d
Root_Path=`cat /var/bt_setupPath.conf`
Setup_Path=$Root_Path/server/mysql
Data_Path=$Root_Path/server/data
O_pl=$(cat /www/server/panel/data/o.pl)

soft_start(){
    # 扫描并启动所有服务
    init_scripts=$(ls ${init_path})
    for script in ${init_scripts}; do
        case "${script}" in
        "bt"|"mysqld"|"nginx"|"httpd")
            continue
            ;;
        esac

        ${init_path}/${script} start
    done

    if [ -f ${init_path}/nginx ]; then
        ${init_path}/nginx start
    elif [ -f ${init_path}/httpd ]; then
        ${init_path}/httpd start
    fi

    ${init_path}/bt stop
    ${init_path}/bt start

    pkill crond
    /sbin/crond

    chmod 600 /etc/ssh/ssh_host_*
    /usr/sbin/sshd -D &
}

init_mysql(){
    if [ "${O_pl}" != "docker_btlamp_d12" ] && [ "${O_pl}" != "docker_btlnmp_d12" ];then
        return
    fi
    if [ -d "${Data_Path}" ]; then
        check_z=$(ls "${Data_Path}")
        echo "check_z:"
        echo ${check_z}
        if [[ ! -z "${check_z}" ]]; then
            echo "check_z is not empty"
            return
        fi
    fi
    if [ -f /init_mysql.sh ] && [ -d "${Setup_Path}" ];then
        sh /init_mysql.sh
        rm -f /init_mysql.sh
    fi
}

is_empty_Data(){
    return "$(ls -A ${Data_Path}/|wc -w)"
}

start_mysql(){
    if [ -d "${Setup_Path}" ] && [ -f "${init_path}/mysqld" ];then
        chown -R mysql:mysql ${Data_Path}
        chgrp -R mysql ${Setup_Path}/.
        ${init_path}/mysqld start
    fi
}

is_empty_Data > /dev/null
init_mysql > /dev/null
start_mysql > /dev/null
soft_start > /dev/null
#tail -f /dev/null
${init_path}/bt log