#!/bin/bash
#Program:
#	安装etcd
# 	node [3-5]
#author: yinshixiong
#mail: yinshx@yonyou.com
#date: 2019/5/31

#调用脚本
. ./initEcs.sh
. ./createServiceCert.sh
. ./globalClusterInfo.sh
. ./oneNodeCreateHttpsCert.sh

clusterArray

#----------------------------Global Variables----------------------------#

#shell_dir=$(cd "$(dirname "$0")"; pwd)
#old_dir=$PWD
#etcdConfig="/etc/etcd/etcd.conf"
#etcdService="/usr/lib/systemd/system"
#etcdCommandPath="../tools"
#etcdCommandPath="/usr/local/bin"
#EtcdServiceName="etcd.service"
#
#backupDataPath="/data/backup_etcd"
#etcdConfPath="/etc/etcd"
#ca_conf="/etc/ssl/etcd/ssl/ca.crt"
#crt_conf="/etc/ssl/etcd/ssl/clientNoHost.crt"
#key_conf="/etc/ssl/etcd/ssl/clientNoHost-key.crt"
#etcdCertPath='/etc/ssl/etcd/ssl'
#etcdDataPath="/data/etcd/data"

function getNodeInfo () {
	local nodeMax=${#server_arrays[@]}
	local l=1
        while [ $l -le $nodeMax ]
	do
	    serverArrayIndex=$[l - 1]
	    echo "${server_arrays[$serverArrayIndex]} server${l}"
	    let l++
	done
}

#判断选择
function NextorQuit () {

    local yourChoose
    local chooseNum=0
    until [ $chooseNum -eq 1 ]
    do
    	echo -e "\e[1;35m已经存在etcd data，请确认是否需要继续保留\e[0m"
        echo -n -e "\e[1;35m[$(date +%Y-%m-%d' '%H:%M:%S)] [INFO] [  继续还是退出:(yes|no)  ]\e[0m"
        read yourChoose
        case $yourChoose in
yes|YES)
    echo -e "\e[1;32m[$(date +%Y-%m-%d' '%H:%M:%S)] [INFO]] [保留]\e[0m"
    choose_etcd='yes'
    break 1
;;
no|NO)
    echo "不保留，9秒后为您删除/data/etcd/data/目录"
    for i in `seq 9 | sort -r`
    do
    echo -e -n "\r\e[K\e[32m不保留，\e[1;41m${i}秒\e[0m\e[32m后为您删除/data/etcd/data/目录,终止请按[ctrl+c]\e[0m"
    sleep 1
    done

	rm -rf ${etcdDataPath}
	choose_etcd ='no'
    break 1
;;
*)
       continue
;;
       esac
done

}

#创建etcd data dir
function createEtcdDataPath () {
    if [ ! -d ${backupDataPath} ];then
        echo "建立${backupDataPath}目录"
        mkdir -pv ${backupDataPath} &>/dev/null
    fi

    if [ ! -d ${etcdDataPath} ];then
        mkdir -p ${etcdDataPath} &>/dev/null
    else
        echo "已经存在${etcdDataPath},是否需要清理"
        NextorQuit
    fi
    [[ ! -d ${etcdConfPath} ]] && mkdir -p ${etcdConfPath} &>/dev/null
    [[ ! -d ${etcdCertPath} ]] && mkdir -p ${etcdCertPath} &>/dev/null
}

#安装etcd命令
function installEtcd () {
    cd ${shell_dir}
    if [ ! -e ${etcdCommandPath}/etcd ];then
        cp ../tools/etcd /usr/local/sbin/
        cp ../tools/etcd /usr/local/bin/
        chmod +x /usr/local/sbin/etcd
        chmod +x /usr/local/bin/etcd
        printInfo "etcd安装完成"
    else
        printWarning "etcd已安装"
    fi
}

#安装etcdctl命令
function installEtcdctl () {
	if [ ! -e ${etcdCommandPath}/etcdctl ];then
	    cp ../tools/etcdctl /usr/local/bin/
            cp ../tools/etcdctl /usr/local/sbin/
	    chmod +x /usr/local/bin/etcdctl
	    chmod +x /usr/local/sbin/etcdctl
	    printInfo "etcdctl安装完成"
  	else
	    printWarning "etcdctl已安装"
  	fi
}

# etcd命令检查
function checkCommand () {
    `command -v $1 >/dev/null 2>&1` && checkCommandResult=0 || checkCommandResult=1
}
function checkEtcdCommands () {
        local sernn
        for sernn in etcd etcdctl
        do
            checkCommand $sernn
            if [ $checkCommandResult -eq 0 ];then
                printInfo "${sernn}安装成功"
            else
                printWarning "${sernn}安装失败"
                exit 400
            fi
        done
}

#获取集群内member列表
function getEtcdMemberList () {
	checkEtcdCommands
	/usr/local/bin/etcdctl --ca-file=${ca_conf} --cert-file=${crt_conf} --key-file=${key_conf} --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 member list
}

#获取集群状态
function getEtcdClusterStatus () {
	checkEtcdCommands
	/usr/local/bin/etcdctl --ca-file=${ca_conf} --cert-file=${crt_conf} --key-file=${key_conf} --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 cluster-health
}

#获取集群内member列表
function getEtcdMemberListNoCert () {
	checkEtcdCommands
	/usr/local/bin/etcdctl member list
}

#获取集群状态
function getEtcdClusterStatusNoCert () {
	checkEtcdCommands
	/usr/local/bin/etcdctl cluster-health
}

#移除etcd member
function removeEtcdMember () {
	checkEtcdCommands
	/usr/local/bin/etcdctl --ca-file=${ca_conf} --cert-file=${crt_conf} --key-file=${key_conf} --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 member remove $1
}
#移除etcd member
function removeEtcdMemberNoCert () {
	checkEtcdCommands
	/usr/local/bin/etcdctl member remove $1
}

#创建alias快捷命令
function createEtcdctlAliashCommand () {
	if [ ! -f /etc/profile.d/etcd_alias.sh ];then
		touch /etc/profile.d/etcd_alias.sh
	fi


	if ( ! egrep -i 'check_etcd' /etc/profile.d/etcd_alias.sh );then
		echo "alias check_etcd=\"/usr/local/bin/etcdctl --ca-file=${ca_conf} --cert-file=${crt_conf} --key-file=${key_conf} --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379  cluster-health\"" > /etc/profile.d/etcd_alias.sh
		echo "alias get_etcd_members=\"/usr/local/bin/etcdctl --ca-file=${ca_conf} --cert-file=${crt_conf} --key-file=${key_conf} --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379  member list\"" >> /etc/profile.d/etcd_alias.sh
		# 新增
		echo "alias etcdctls=\"ETCDCTL_API=3 /usr/local/bin/etcdctl --cacert=${ca_conf} --cert=${crt_conf} --key=${key_conf} --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379\"" >> /etc/profile.d/etcd_alias.sh
else
	echo -e "\e[1;32malias快捷命令check_etcd和get_etcd_member\e[0m"
	echo -e "\e[1;32mcommand:[check_etcd] 检查etcd状态\e[0m"
	echo -e "\e[1;32mcommand:[get_etcd_member] 检查etcd member状态\e[0m"
fi
}

#启动etcd.service
function startEtcdService () {

	systemctl daemon-reload etcd.service
	systemctl enable etcd.service
	systemctl start etcd.service
	service_status=`systemctl status etcd.service | awk '/Active/{print}' | systemctl status etcd.service | awk '/Active/{print}' | awk '{print $3}' | tr -d '()'`
	if [[ "x${service_status}" == "xrunning" ]];then
		echo -e "\e[1;32mEtcd运行正常\e[0m"
	else
		echo -e "\e[1;31mEtcd运行异常\e[0m"
		exit 404
	fi

}

function chooseYourIpaddr () {
	hostIpArray=(`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`)
	ipnum=${#hostIpArray[@]}
	ipnumarray=$(seq ${ipnum})
	PS3="请选择,哪一个是你宿主机的IP地址,输入序号即可: "

	echo -e "\e[1;37m检索到您的本机共有${ipnum}个ip地址!\e[0m"

	select var in ${hostIpArray[@]}
	do
  		if ! echo ${ipnumarray[@]} | grep -q $REPLY; then
  		echo "please enter [1-${ipnum}]."
  		continue
  		fi
  		break;
	done
}

#关闭etcd.service
function stopEtcdService () {
	service_status=`systemctl status etcd.service | awk '/Active/{print}' | systemctl status etcd.service | awk '/Active/{print}' | awk '{print $3}' | tr -d '()'`
	if [[ "x${service_status}" == "xrunning" ]];then
	    echo -e "\e[1;33m开始关闭Etcd.service\e[0m"
	    systemctl stop etcd.service
	    service_status=`systemctl status etcd.service | awk '/Active/{print}' | systemctl status etcd.service | awk '/Active/{print}' | awk '{print $3}' | tr -d '()'`
	    if [[ "x${service_status}" == "xdead" ]];then
		echo -e "\e[1;33m成功关闭Etcd.service\e[0m"
	    fi
	else
	    echo -e "\e[1;32mEtcd.service已停止无需关闭\e[0m"
	fi
}

function etcdClusterScriptCommandHelpInfo () {
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[35m\t\t\t\t\t\t\t帮助信息:\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	printError "安装3个节点时候需要server_array=3个节点IP"
	printError "安装5个节点时候需要server_array=5个节点IP"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m1. bash $0 -a etcd1 安装etcd1节点[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m2. bash $0 -b etcd2 安装etcd2节点[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m3. bash $0 -c etcd3 安装etcd3节点[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m4. bash $0 -f etcd4 安装etcd4节点[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m5. bash $0 -l etcd5 安装etcd5节点[带证书]\e[0m"
        echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
        echo -e "\e[31m1. bash $0 -x etcd1 安装etcd1节点[不带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
        echo -e "\e[31m2. bash $0 -y etcd2 安装etcd2节点[不带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
        echo -e "\e[31m3. bash $0 -z etcd3 安装etcd3节点[不带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
        echo -e "\e[31m4. bash $0 -m etcd4 安装etcd4节点[不带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
        echo -e "\e[31m5. bash $0 -n etcd5 安装etcd5节点[不带证书]\e[0m"
        echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m1. bash $0 -G 获取etcd member列表[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m2. bash $0 -S 获取etcd cluster-health[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m3. bash $0 -A etcd节点名称 -U url 添加节点[带证书] example: bash install_service.sh -A etcd3 -U https://10.0.0.1:2380\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[41m4. bash $0 -K 移除etcd member[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m5. bash $0 -L 创建alias快捷命令[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[34m6. bash $0 -p 2/3[api version] -B 10(清理多少天前的备份) 备份服务[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[34m7. bash $0 -p 3 -w [备份db文件] -N [新数据目录] -R 使用api version3 恢复备份\e[0m，\e[31m请注意如果是集群整体迁移，需要在每个节点上执行,切需要指定节点名称[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[32m8. bash $0 -j etcd1 安装单节点,[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[32m9. bash $0 -g 获取etcd member列表[不带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[32m10. bash $0 -s 获取etcd cluster-health[不带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[33m11. bash $0 -e etcd节点名称 -u url 添加节点[不带证书]\e[0m"	
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[32m12. bash $0 -J etcd1 安装单节点,不带证书\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[34m13. bash $0 -p 2/3[api version] -v 10(清理多少天前的备份) 备份服务[不带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[34m14. bash $0 -p 3 -w [备份db文件] -N [新数据目录] -V 节点名称[etcd1..n],使用api version3 恢复备份\e[0m，\e[31m请注意如果是集群整体迁移，需要在每个节点上执行,切需要指定节点名称[不带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[41m15. bash $0 -k 移除etcd member[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[37m16. bash $0 -I 启动服务[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[37m17. bash $0 -i 停止服务[带证书]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[37m18. bash $0 -h 查看帮助信息\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
	echo -e "\e[41m19. bash $0 -r 移除etcd服务和数据目录[谨慎操作]\e[0m"
	echo -e "\e[31m----------------------------------------------------------------------------------------------------------------------------\e[0m"
}

function backup_etcd_db () {

	case $1 in
2)
	backup_time=$(date +%Y-%m-%d-%H-%M)
	if [ ! -e ${backup__etcd_path}/${backup_time}.etcd ];then
		mkdir -p ${backupDataPath}/${backup_time}.etcd &>/dev/null
	fi
	#api version = 2
	ETCDCTL_API=${get_api_version} /usr/local/bin/etcdctl --ca-file=${ca_conf} \
	--cert-file=${crt_conf} \
	--key-file=${key_conf} \
	--endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 \
	backup --data-dir ${etcdDataPath} \
	--backup-dir ${backupDataPath}/${backup_time}.etcd/

	cd ${backupDataPath}/${backup_time}.etcd/

	tar -zcvf etcd.$(date +%Y-%m-%d-%H-%M-%S).tar.gz ${backupDataPath}/${backup_time}.etcd/

	find ${backupDataPath}/ -ctime +${remove_time} -exec rm -r {} \;

	echo "${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd/" >> ${backupDataPath}/version2_backup.log
;;

3)
	ETCDCTL_API=3 /usr/local/bin/etcdctl snapshot save ${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd.db --cacert="${ca_conf}" --cert="${crt_conf}" --key="${key_conf}" --endpoints=127.0.0.1:2379
	echo "${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd.db" >> ${backupDataPath}/version3_backup.log
;;

*)
	echo -e "\e[1;35m Etcd API VERSION MUST BE 2 || 3 \e[0m"
;;
esac
}

function backup_etcd_db_nocert () {

	case $1 in
2)
	backup_time=$(date +%Y-%m-%d-%H-%M)
	if [ ! -e ${backup__etcd_path}/${backup_time}.etcd ];then
		mkdir -p ${backupDataPath}/${backup_time}.etcd &>/dev/null
	fi
	#api version = 2
	ETCDCTL_API=${get_api_version} /usr/local/bin/etcdctl --endpoints=http://etcd1:2379,http://etcd2:2379,http://etcd3:2379 \
	backup --data-dir ${etcdDataPath} \
	--backup-dir ${backupDataPath}/${backup_time}.etcd/

	cd ${backupDataPath}/${backup_time}.etcd/

	tar -zcvf etcd.$(date +%Y-%m-%d-%H-%M-%S).tar.gz ${backupDataPath}/${backup_time}.etcd/

	find ${backupDataPath}/ -ctime +${remove_time} -exec rm -r {} \;

	echo "${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd/" >> ${backupDataPath}/version2_backup.log
;;

3)
	ETCDCTL_API=3 /usr/local/bin/etcdctl snapshot save ${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd.db --endpoints=127.0.0.1:2379
	echo "${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd.db" >> ${backupDataPath}/version3_backup.log
;;

*)
	echo -e "\e[1;35m Etcd API VERSION MUST BE 2 || 3 \e[0m"
;;
esac
}

function restore_etcd_db () {
	if [ ! -d ${backup_path} ];then
		echo -e "\e[1;41m没有可用于恢复的db备份\e[0m"
		exit 1
	fi
	#数据同步命令
	#curl http://127.0.0.1:2379/v2/members/member_id -XPUT -H "Content-Type:application/json" -d '{"peerURLs":["http://127.0.0.1:2379"]}'
	case $1 in
2)
	#api version = 2
	echo "会破坏当前集群，此方法只使用将备份文件，拷贝到其他新的etcd集群中，进行恢复操作"
	sleep 10
	echo "终止请按Ctrl + c"
	# 强制终止
	exit 2
	ETCDCTL_API=${get_api_version} /usr/local/bin/etcdctl --ca-file=${ca_conf} \
	--cert-file=${crt_conf} \
	--key-file=${key_conf} \
	--endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 \
	--data-dir ${backupDataPath}/${backup_time}.etcd/ -force-new-cluster

	cd ${backupDataPath}/${backup_time}.etcd/
	tar -zcvf etcd.$(date +%Y-%m-%d-%H-%M-%S).tar.gz ${backupDataPath}/${backup_time}.etcd/
	find ${backupDataPath}/ -ctime +${remove_time} -exec rm -r {} \;
	echo "${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd/" >> ${backupDataPath}/version2_backup.log
;;

3)
	# 默认恢复最后一条备份记录
	# --name 重新指定一个数据目录,可以不指定，默认为default.etcd
	# --data-dir : 指定数据目录
	# ETCDCTL_API=3
	if [ -z ${path_dir} ];then
		echo "-w 后需要跟db文件绝对路径"
		exit 111
	fi

	defaultPath='default.etcd'

	ETCDCTL_API=3 /usr/local/bin/etcdctl snapshot restore ${path_dir} --name ${node_names} --cacert="${ca_conf}" --cert="${crt_conf}" --key="${key_conf}" --data-dir=${new_data_dir}
    echo -e "\e[1;35m默认恢复上次备份etcd.db文件\e[0m"
	#etcdctl snapshot restore `tail -n 1 ${backupDataPath}/version3_backup.log` --cacert="${ca_conf}" --cert="${crt_conf}" --key="${key_conf}" --data-dir=${new_data_dir}
	echo "${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd.db" >> ${backupDataPath}/version3_backup.log
;;

*)
	echo -e "\e[1;35m apiversion must be 2 || 3"
;;
esac



}


function restore_etcd_db_nocert () {
	if [ ! -d ${backup_path} ];then
		echo -e "\e[1;41m没有可用于恢复的db备份\e[0m"
		exit 1
	fi
	#数据同步命令
	#curl http://127.0.0.1:2379/v2/members/member_id -XPUT -H "Content-Type:application/json" -d '{"peerURLs":["http://127.0.0.1:2379"]}'
	case $1 in
2)
	#api version = 2
	echo "会破坏当前集群，此方法只使用将备份文件，拷贝到其他新的etcd集群中，进行恢复操作"
	sleep 10
	echo "终止请按Ctrl + c"
	# 强制终止
	exit 2
	ETCDCTL_API=${get_api_version} /usr/local/bin/etcdctl --endpoints=http://etcd1:2379,http://etcd2:2379,http://etcd3:2379 \
	--data-dir ${backupDataPath}/${backup_time}.etcd/ -force-new-cluster

	cd ${backupDataPath}/${backup_time}.etcd/
	tar -zcvf etcd.$(date +%Y-%m-%d-%H-%M-%S).tar.gz ${backupDataPath}/${backup_time}.etcd/
	find ${backupDataPath}/ -ctime +${remove_time} -exec rm -r {} \;
	echo "${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd/" >> ${backupDataPath}/version2_backup.log
;;

3)
	# 默认恢复最后一条备份记录
	# --name 重新指定一个数据目录,可以不指定，默认为default.etcd
	# --data-dir : 指定数据目录
	# ETCDCTL_API=3
	if [ -z ${path_dir} ];then
		echo "-w 后需要跟db文件绝对路径"
		exit 111
	fi

	defaultPath='default.etcd'

	ETCDCTL_API=3 /usr/local/bin/etcdctl snapshot restore ${path_dir} --name ${node_names} --data-dir=${new_data_dir}
    echo -e "\e[1;35m默认恢复上次备份etcd.db文件\e[0m"
	#etcdctl snapshot restore `tail -n 1 ${backupDataPath}/version3_backup.log` --cacert="${ca_conf}" --cert="${crt_conf}" --key="${key_conf}" --data-dir=${new_data_dir}
	echo "${backupDataPath}/$(date +%Y-%m-%d-%H-%M-%S).etcd.db" >> ${backupDataPath}/version3_backup.log
;;

*)
	echo -e "\e[1;35m apiversion must be 2 || 3"
;;
esac

}

nodeNumbs=${#server_arrays[@]}

while getopts ":ra:b:c:d:A:D:U:B:p:w:N:j:x:f:l:m:n:y:v:V:z:e:u:J:R:GSgsKkiILH-help" OPTS
do
	case ${OPTS} in
a)
	nodeName="${OPTARG}"
	if [ -z ${nodeName} ];then
		echo "bash $0 node1或者node2或者node3,不能为空"
		exit 7
	fi

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	createEtcdDataPath
	installEtcd
	installEtcdctl
	reset_machine
	create_crt_fun
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	if [ ! -f ${etcdConfig} ];then
		cd ${shell_dir}
		echo -e "开始拷贝etcd.conf ${etcdConfig}"
		if [ $nodeNumbs -eq 3 ];then
		    cp ../conf/etcd1-3.conf ${etcdConfig}
                    sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                    sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                    sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                    sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                    sed -i "s#%node1%#${nodeName}#g" ${etcdConfig}
		elif [ $nodeNumbs -eq 5 ];then
		    cp ../conf/etcd1-5.conf ${etcdConfig}
                    sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                    sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                    sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                    sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                    sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
                    sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
                    sed -i "s#%node1%#${nodeName}#g" ${etcdConfig}
                else
                    printWarning "节点必须为3个节点或者5个节点"
                    exit 87
		fi
	else
	    echo "${etcdConfig}下已存在etcd.conf"
	    exit 5
        fi

	if [ ! -f ${etcdService}/${EtcdServiceName} ];then
	    echo -e "开始拷贝etcd.service ${etcdService}/"
	    cp ../service/etcd.service ${etcdService}/
	    sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
	    sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
	else
	    echo "${etcdService}下已存在${EtcdServiceName}"
	    exit 9
	fi
	    startEtcdService
;;

b)
    nodeName="${OPTARG}"
    if [ -z ${nodeName} ];then
	echo "bash $0 etcd1 or etcd2 or etcd3 or etcd4 or etcd5,不能为空"
	exit 10
    fi
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	createEtcdDataPath
	installEtcd
	installEtcdctl
	reset_machine
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	read -p "请输入sshd port,默认为22: " sshd_port
	sshd_port=${sshd_port:-22}
	scp -P ${sshd_port} root@${server_arrays[0]}:/etc/ssl/etcd/ssl/* /etc/ssl/etcd/ssl/
	echo -e "\e[1;41m记得删除其他服务器的证书\e[0m"
	if [ ! -f ${etcdConfig} ];then
	    cd ${shell_dir}
	    echo -e "开始拷贝etcd.conf ${etcdConfig}"
            if [ $nodeNumbs -eq 3 ];then
                cp ../conf/etcd2-3.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node2%#${nodeName}#g" ${etcdConfig}
            elif [ $nodeNumbs -eq 5 ];then
                cp ../conf/etcd2-5.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
                sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
                sed -i "s#%node2%#${nodeName}#g" ${etcdConfig}
            else
                printWarning "节点必须为3个节点或者5个节点"
                exit 86
            fi
        else
	    echo "${etcdConfig}下已存在etcd.conf"
	    exit 5
        fi

	if [ ! -f ${etcdService}/${EtcdServiceName} ];then
	    echo -e "开始拷贝etcd.service ${etcdService}/"
	    cp ../service/etcd.service ${etcdService}/
	    sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
	    sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
	else
	    echo "${etcdService}下已存在${EtcdServiceName}"
	    exit 11
	fi
	startEtcdService
;;

c)
	nodeName="${OPTARG}"
	if [ -z ${nodeName} ];then
            echo "bash $0 etcd1 or etcd2 or etcd3 or etcd4 or etcd5,不能为空"
	    exit 12
	fi
	
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	createEtcdDataPath
	installEtcd
	installEtcdctl
	reset_machine
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	read -p "请输入sshd port,默认为22: " sshd_port
	sshd_port=${sshd_port:-22}
	scp -P ${sshd_port} root@${server_arrays[0]}:/etc/ssl/etcd/ssl/* /etc/ssl/etcd/ssl/
	echo -e "\e[1;41m记得删除其他服务器的证书\e[0m"

	if [ ! -f ${etcdConfig} ];then
	    echo -e "开始拷贝etcd.conf ${etcdConfig}"
            if [ $nodeNumbs -eq 3 ];then
                cp ../conf/etcd3-3.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node3%#${nodeName}#g" ${etcdConfig}
            elif [ $nodeNumbs -eq 5 ];then
                cp ../conf/etcd3-5.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
                sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
                sed -i "s#%node3%#${nodeName}#g" ${etcdConfig}
            else
                printWarning "节点必须为3个节点或者5个节点"
                exit 85
            fi
	else
	    echo "${etcdConfig}下已存在etcd.conf"
	    exit 13
	fi

	if [ ! -f ${etcdService}/${EtcdServiceName} ];then
	    echo -e "开始拷贝etcd.service ${etcdService}/"
	    cp ../service/etcd.service ${etcdService}/
	    sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
	    sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
	else
	    echo "${etcdService}下已存在${EtcdServiceName}"
	    exit 14
	fi
	startEtcdService
;;

f)
        nodeName="${OPTARG}"
        if [ -z ${nodeName} ];then
            echo "bash $0 etcd1 or etcd2 or etcd3 or etcd4 or etcd5,不能为空"
            exit 12
        fi

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        createEtcdDataPath
        installEtcd
        installEtcdctl
        reset_machine
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        read -p "请输入sshd port,默认为22: " sshd_port
        sshd_port=${sshd_port:-22}
        scp -P ${sshd_port} root@${server_arrays[0]}:/etc/ssl/etcd/ssl/* /etc/ssl/etcd/ssl/
        echo -e "\e[1;41m记得删除其他服务器的证书\e[0m"

        if [ ! -f ${etcdConfig} ];then
            echo -e "开始拷贝etcd.conf ${etcdConfig}"
            if [ $nodeNumbs -eq 5 ];then
                cp ../conf/etcd4-5.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
                sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
                sed -i "s#%node4%#${nodeName}#g" ${etcdConfig}
            else
                printWarning "节点必须为3个节点或者5个节点"
                exit 88
            fi
        else
            echo "${etcdConfig}下已存在etcd.conf"
            exit 13
        fi

        if [ ! -f ${etcdService}/${EtcdServiceName} ];then
            echo -e "开始拷贝etcd.service ${etcdService}/"
            cp ../service/etcd.service ${etcdService}/
            sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
            sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
        else
            echo "${etcdService}下已存在${EtcdServiceName}"
            exit 14
        fi
        startEtcdService
;;

l)
        nodeName="${OPTARG}"
        if [ -z ${nodeName} ];then
            echo "bash $0 etcd1 or etcd2 or etcd3 or etcd4 or etcd5,不能为空"
            exit 12
        fi
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        createEtcdDataPath
        installEtcd
        installEtcdctl
        reset_machine
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        read -p "请输入sshd port,默认为22: " sshd_port
        sshd_port=${sshd_port:-22}
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        scp -P ${sshd_port} root@${server_arrays[0]}:/etc/ssl/etcd/ssl/* /etc/ssl/etcd/ssl/
        echo -e "\e[1;41m记得删除其他服务器的证书\e[0m"
        if [ ! -f ${etcdConfig} ];then
            echo -e "开始拷贝etcd.conf ${etcdConfig}"
            if [ $nodeNumbs -eq 5 ];then
                cp ../conf/etcd5-5.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
                sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
                sed -i "s#%node5%#${nodeName}#g" ${etcdConfig}
            else
                printWarning "节点必须为3个节点或者5个节点"
                exit 89
            fi
        else
            echo "${etcdConfig}下已存在etcd.conf"
            exit 13
        fi

        if [ ! -f ${etcdService}/${EtcdServiceName} ];then
            echo -e "开始拷贝etcd.service ${etcdService}/"
            cp ../service/etcd.service ${etcdService}/
            sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
            sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
        else
            echo "${etcdService}下已存在${EtcdServiceName}"
            exit 14
        fi
        startEtcdService
;;

r)
    echo "10秒后开始清理etcd服务及/data/etcd/data目录"
    for i in `seq 2 | sort -nrk 1`
    do
        echo -e -n "\r\e[K\e[32m不保留，\e[1;41m${i}秒\e[0m\e[32m后
        为您删除以下目标:
        /data/etcd/
        /etc/etcd/
        /usr/local/bin/etcd
        /usr/local/bin/etcdctl
        /usr/lib/systemd/system/etcd.service
        终止请按[ctrl+c]\e[0m"
        sleep 1
    done
	rm -rf /etc/ssl/etcd
	if [ ! -d /data/etcdData/ ];then
	    mkdir /data/etcdData
	fi
	cp -r /data/etcd/ /data/etcdData/etcddata_$(date +%Y%m%d%H%M%S)
	rm -rf /data/etcd/
	rm -rf /usr/lib/systemd/system/etcd.service
	\cp /etc/etcd/etcd.conf /etc/etcd/etcd.conf.$(date +%Y%m%d%H%M%S).bak &>/dev/null
	rm -rf /etc/etcd/etcd.conf
	systemctl stop etcd.service &>/dev/null
	systemctl disable etcd.service &>/dev/null
	rm -rf /usr/local/bin/etcd
	rm -rf /usr/local/bin/etcdctl
	rm -rf /usr/local/sbin/etcd
	rm -rf /usr/local/sbin/etcdctl
;;

G)
	getEtcdMemberList
;;

S)
	getEtcdClusterStatus
;;

g)
	getEtcdMemberListNoCert
;;

s)
	getEtcdClusterStatusNoCert
;;

K)
        getEtcdClusterStatus
        #获取不健康的member,添加到数组
        unhealthy_array=(`sh install_service.sh -S | awk '/unreachable/' | awk '{print $2}'`)
        #获取个数
        unhealthy_number=${#unhealthy_array[@]}
        if [ ${unhealthy_number} -eq 0 ];then
        	echo -e "\e[7;32m恭喜etcd集群member正常\e[0m"
        	exit 0
        else
        	echo -e "\e[1;41m共有${unhealthy_number}个不健康的member\e[0m"
   	        memberNumber=1
            for members_id in ${unhealthy_array[@]}
            do
        	    echo "第${memberNumber}个不健康的[ETCD MEMBER ID] = ${members_id}"
        		let memberNumber++
        	done
        	echo -e "\e[1;41m接下来即将让您输入要移除的[ETCD MEMBER ID]: \e[0m"
        	read -p "请谨慎输入: " etcd_members
        	if [ ! -z ${etcd_members} ];then
            	removeEtcdMember ${etcd_members}
    		else
            	echo "不能为空"
            	exit 16
    		fi
    	fi
;;

k)
        getEtcdClusterStatusNoCert
        #获取不健康的member,添加到数组
        unhealthy_array=(`sh install_service.sh -s | awk '/unreachable/' | awk '{print $2}'`)
        #获取个数
        unhealthy_number=${#unhealthy_array[@]}
        if [ ${unhealthy_number} -eq 0 ];then
        	echo -e "\e[7;32m恭喜etcd集群member正常\e[0m"
        	exit 0
        else
        	echo -e "\e[1;41m共有${unhealthy_number}个不健康的member\e[0m"
   	        memberNumber=1
            for members_id in ${unhealthy_array[@]}
            do
        	    echo "第${memberNumber}个不健康的[ETCD MEMBER ID] = ${members_id}"
        		let memberNumber++
        	done
        	echo -e "\e[1;41m接下来即将让您输入要移除的[ETCD MEMBER ID]: \e[0m"
        	read -p "请谨慎输入: " etcd_members
        	if [ ! -z ${etcd_members} ];then
            	removeEtcdMemberNoCert ${etcd_members}
    		else
            	echo "不能为空"
            	exit 16
    		fi
    	fi
;;

A)
	#添加节点sh install_service.sh -A etcd节点 -U https://etcd节点:2380
	memberName=${OPTARG}

;;

e)
	#添加节点sh install_service.sh -e etcd节点 -U http://etcd节点:2380
	memberName=${OPTARG}
;;

u)
	add_member_url=${OPTARG}
	checkEtcdCommands
	# 添加member的信息
	# bash install_service.sh -A etcd3 -U https://172.17.174.37:2380
	echo -e "\e[1;34mbash install_service.sh -A etcd3 -U https://172.17.174.37:2380\e[0m"
	echo -e "\e[1;34m1.注意需要先将添加的member所在机器的etcd服务进行停止，再进行添加member操作，否则报错。\e[0m"
	echo -e "\e[1;34m2.注意需要将该节点etcd data目录删除，并重新建立mkdir /data/etcd/data\e[0m"
	echo -e "\e[1;34m3.注意如是故障节点重新接入，需要在该节点service配置加启动参数\e[0m"
	echo -e "\e[1;35m  3.1 vim /usr/lib/systemd/system/etcd.service\e[0m"
	echo -e "\e[1;35m  3.2 ExecStart=/usr/local/bin/etcd -initial-cluster-state existing\e[0m"
	echo -e "\e[1;34m4.systemctl daemon-reload && systemctl restart etcd.service\e[0m"
    /usr/local/bin/etcdctl member add ${memberName} ${add_member_url}

;;

U)
	add_member_url=${OPTARG}

	checkEtcdCommands

	echo -e "\e[1;34m1.注意需要先将添加的member所在机器的etcd服务进行停止，再进行添加member操作，否则报错。\e[0m"
	echo -e "\e[1;34m2.注意需要将该节点etcd data目录删除，并重新建立\e[0m"
	echo -e "\e[1;34m3.注意如是故障节点重新接入，需要在该节点service配置加启动参数\e[0m"
	echo -e "\e[1;35m  3.1 vim /usr/lib/systemd/system/etcd.service\e[0m"
	echo -e "\e[1;35m  3.2 ExecStart=/usr/local/bin/etcd -initial-cluster-state existing\e[0m"
	echo -e "\e[1;34m4.systemctl daemon-reload && systemctl restart etcd.service\e[0m"
    /usr/local/bin/etcdctl --ca-file=${ca_conf} --cert-file=${crt_conf} --key-file=${key_conf} --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 member add ${memberName} ${add_member_url}


;;

L)
	#创建alias
	createEtcdctlAliashCommand
	source /etc/profile.d/etcd_alias.sh

;;

B)
	remove_time=${OPTARG}
	#备份etcd
	backup_etcd_db ${get_api_version}
	#ETCDCTL_API=3 etcdctl snapshot save /data/test.db --cacert="/etc/ssl/etcd/ssl/ca.crt" --cert="/etc/ssl/etcd/ssl/etcd.crt" --key="/etc/ssl/etcd/ssl/etcd.key" --endpoints=127.0.0.1:2379
;;


v)
	remove_time=${OPTARG}
	backup_etcd_db_nocert ${get_api_version}
;;

R)
	#恢复
	node_names=${OPTARG}
	restore_etcd_db ${get_api_version}
;;

V)
	#恢复
	node_names=${OPTARG}
	restore_etcd_db_nocert ${get_api_version}
;;
D)
    #删除etcd备份
    rm_days=${OPTARG}
    find ${backupDataPath}/ -ctime +${rm_days} -exec rm -r {} \;
    echo "${backupDataPath}/ ${rm_days}天前备份文件删除成功"

;;

p)
	#指定api version
	get_api_version=${OPTARG}
;;

N)
	#用于恢复数据时指定新的数据目录
	# bash $0 -w /path/etcd.db -N /data/newdir -p 3 -R
	new_data_dir=${OPTARG}
;;

w)
	path_dir=${OPTARG}
;;

j)
        nodeName="${OPTARG}"
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	createEtcdDataPath
	installEtcd
	installEtcdctl
	reset_machine
	#cd ../cfsslExtendCluster/
	#sh extandCluster.sh -C
	#./extandCluster.sh -S server-IP -I server_id -G 生
	createOneNodeCert
	#createOneNodeCert
	#create_crt_fun
	# install_stand_alone
	chooseYourIpaddr
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	if [ ! -f ${etcdConfig} ];then
	    cd ${shell_dir}
	    echo -e "开始拷贝etcd.conf ${etcdConfig}"
	    cp ../conf/etcd.conf ${etcdConfig}
	    sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
	    sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
	    sed -i "s#%node1%#${nodeName}#g" ${etcdConfig}
	else
	    echo "${etcdConfig}下已存在etcd.conf"
	    exit 5
	fi

	if [ ! -f ${etcdService}/${EtcdServiceName} ];then
		echo -e "开始拷贝etcd.service ${etcdService}/"
		cp ../service/etcd.service ${etcdService}/
		sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
		sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
	else
		echo "${etcdService}下已存在${EtcdServiceName}"
		exit 9
	fi
	startEtcdService
;;

J)
	nodeName="${OPTARG}"
	if [[ "X${nodeName}" == "X" ]];then
	    echo "bash $0 node name,不能为空"
	    exit 13
	fi
	createEtcdDataPath
	installEtcd
	installEtcdctl
	reset_machine
	chooseYourIpaddr
	if [ ! -f ${etcdConfig} ];then
		cd ${shell_dir}
		echo -e "开始拷贝etcd.conf ${etcdConfig}"
		cp ../conf/etcd.conf ${etcdConfig}
		sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
		sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
		sed -i "s#%node1%#${nodeName}#g" ${etcdConfig}
		sed -i '/ssl/d' ${etcdConfig}
		sed -i 's#https#http#g' ${etcdConfig}
	else
		echo "${etcdConfig}下已存在etcd.conf"
		exit 5
fi

	if [ ! -f ${etcdService}/${EtcdServiceName} ];then
		echo -e "开始拷贝etcd.service ${etcdService}/"
		cp ../service/etcd.service ${etcdService}/
		sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
		sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
	else
		echo "${etcdService}下已存在${EtcdServiceName}"
		exit 9
	fi
	startEtcdService
;;

x)
	nodeName="${OPTARG}"
	if [ -z ${nodeName} ];then
	    echo "bash $0 node1或者node2或者node3,不能为空"
	    exit 7
	fi


        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	createEtcdDataPath
	installEtcd
	installEtcdctl
	reset_machine
	#create_crt_fun
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

	if [ ! -f ${etcdConfig} ];then
	    cd ${shell_dir}
	    echo -e "开始拷贝etcd.conf ${etcdConfig}"
	    if [ $nodeNumbs -eq 3 ];then
	        cp ../conf/etcd1-3-http.conf ${etcdConfig}
	        sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
	        sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
	        sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
	        sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
	        sed -i "s#%node1%#${nodeName}#g" ${etcdConfig}
	        #sed -i '/ssl/d' ${etcdConfig}
	        sed -i 's/https/http/g' ${etcdConfig}
	    elif [ $nodeNumbs -eq 5 ];then
                cp ../conf/etcd1-5-http.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
                sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
                sed -i "s#%node1%#${nodeName}#g" ${etcdConfig}
                #sed -i '/ssl/d' ${etcdConfig}
                sed -i 's/https/http/g' ${etcdConfig}
            else
                printWarning "节点必须为3个节点或者5个节点"
                exit 0
	    fi
	else
	        echo "${etcdConfig}下已存在etcd.conf"
	        #sed -i '/ssl/d' ${etcdConfig}
	        sed -i 's/https/http/g' ${etcdConfig}
	        exit 5
	fi

	if [ ! -f ${etcdService}/${EtcdServiceName} ];then
	    echo -e "开始拷贝etcd.service ${etcdService}/"
	    cp ../service/etcd.service ${etcdService}/
	    sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
	    sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
	else
	    echo "${etcdService}下已存在${EtcdServiceName}"
	    exit 9
	fi
	startEtcdService
;;

y)
        nodeName="${OPTARG}"
        if [ -z ${nodeName} ];then
            echo "bash $0 node1或者node2或者node3,不能为空"
            exit 10
        fi

	createEtcdDataPath
	installEtcd
	installEtcdctl
	reset_machine

	#create_crt_fun
	#read -p "请输入sshd port,默认为22: " sshd_port
	#sshd_port=${sshd_port:-22}
	#scp -P ${sshd_port} root@${server_arrays[0]}:/etc/ssl/etcd/ssl/* /etc/ssl/etcd/ssl/
        if [ ! -f ${etcdConfig} ];then
            cd ${shell_dir}
            echo -e "开始拷贝etcd.conf ${etcdConfig}"
            if [ $nodeNumbs -eq 3 ];then
                cp ../conf/etcd2-3-http.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node2%#${nodeName}#g" ${etcdConfig}
                #sed -i '/ssl/d' ${etcdConfig}
                sed -i 's/https/http/g' ${etcdConfig}
            elif [ $nodeNumbs -eq 5 ];then
                cp ../conf/etcd2-5-http.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
                sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
                sed -i "s#%node2%#${nodeName}#g" ${etcdConfig}
                #sed -i '/ssl/d' ${etcdConfig}
                sed -i 's/https/http/g' ${etcdConfig}
            else
                printWarning "节点必须为3个节点或者5个节点"
                exit 0
	    fi
            else
                echo "${etcdConfig}下已存在etcd.conf"
                #sed -i '/ssl/d' ${etcdConfig}
                sed -i 's/https/http/g' ${etcdConfig}
                exit 5
            fi

	    if [ ! -f ${etcdService}/${EtcdServiceName} ];then
		echo -e "开始拷贝etcd.service ${etcdService}/"
		cp ../service/etcd.service ${etcdService}/
		sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
		sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
	    else
		echo "${etcdService}下已存在${EtcdServiceName}"
		exit 11
	    fi
		startEtcdService
;;

z)
	nodeName="${OPTARG}"
	if [ -z ${nodeName} ];then
		echo "bash $0 node1或者node2或者node3,不能为空"
		exit 12
	fi

	createEtcdDataPath
	installEtcd
	installEtcdctl
	reset_machine

	# create_crt_fun
	# read -p "请输入sshd port,默认为22: " sshd_port
	# sshd_port=${sshd_port:-22}
	# scp -P ${sshd_port} root@${server_arrays[0]}:/etc/ssl/etcd/ssl/* /etc/ssl/etcd/ssl/

    if [ ! -f ${etcdConfig} ];then
        cd ${shell_dir}
        echo -e "开始拷贝etcd.conf ${etcdConfig}"
        if [ $nodeNumbs -eq 3 ];then
            cp ../conf/etcd3-3-http.conf ${etcdConfig}
            sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
            sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
            sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
            sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
            sed -i "s#%node3%#${nodeName}#g" ${etcdConfig}
            #sed -i '/ssl/d' ${etcdConfig}
            sed -i 's/https/http/g' ${etcdConfig}
        elif [ $nodeNumbs -eq 5 ];then
            cp ../conf/etcd3-5-http.conf ${etcdConfig}
            sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
            sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
            sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
            sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
            sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
            sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
            sed -i "s#%node3%#${nodeName}#g" ${etcdConfig}
            #sed -i '/ssl/d' ${etcdConfig}
            sed -i 's/https/http/g' ${etcdConfig}
        else
            printWarning "节点必须为3个节点或者5个节点"
            exit 0
	fi
    else
        echo "${etcdConfig}下已存在etcd.conf"
        #sed -i '/ssl/d' ${etcdConfig}
        sed -i 's/https/http/g' ${etcdConfig}
        exit 5
    fi

    if [ ! -f ${etcdService}/${EtcdServiceName} ];then
        echo -e "开始拷贝etcd.service ${etcdService}/"
        cp ../service/etcd.service ${etcdService}/
        sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
        sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
    else
        echo "${etcdService}下已存在${EtcdServiceName}"
        exit 11
    fi
        startEtcdService
;;
m)
        nodeName="${OPTARG}"
        if [ -z ${nodeName} ];then
            echo "bash $0 node1或者node2或者node3,不能为空"
            exit 12
        fi
        createEtcdDataPath
        installEtcd
        installEtcdctl
        reset_machine
        if [ ! -f ${etcdConfig} ];then
            cd ${shell_dir}
            echo -e "开始拷贝etcd.conf ${etcdConfig}"
            if [ $nodeNumbs -eq 5 ];then
                cp ../conf/etcd4-5-http.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
                sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
                sed -i "s#%node4%#${nodeName}#g" ${etcdConfig}
                #sed -i '/ssl/d' ${etcdConfig}
                sed -i 's/https/http/g' ${etcdConfig}
            else
                printWarning "节点必须为3个节点或者5个节点"
                exit 0
            fi
        else
            echo "${etcdConfig}下已存在etcd.conf"
            #sed -i '/ssl/d' ${etcdConfig}
            sed -i 's/https/http/g' ${etcdConfig}
            exit 5
        fi

    if [ ! -f ${etcdService}/${EtcdServiceName} ];then
        echo -e "开始拷贝etcd.service ${etcdService}/"
        cp ../service/etcd.service ${etcdService}/
        sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
        sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
    else
        echo "${etcdService}下已存在${EtcdServiceName}"
        exit 11
    fi
        startEtcdService
;;

n)
        nodeName="${OPTARG}"
        if [ -z ${nodeName} ];then
            echo "bash $0 node1或者node2或者node3,不能为空"
            exit 12
        fi
        createEtcdDataPath
        installEtcd
        installEtcdctl
        reset_machine
        if [ ! -f ${etcdConfig} ];then
            cd ${shell_dir}
            echo -e "开始拷贝etcd.conf ${etcdConfig}"
            if [ $nodeNumbs -eq 5 ];then
                cp ../conf/etcd5-5-http.conf ${etcdConfig}
                sed -i "s#%datadir%#${etcdDataPath}#g" ${etcdConfig}
                sed -i "s#%node1_ip%#${server_arrays[0]}#g" ${etcdConfig}
                sed -i "s#%node2_ip%#${server_arrays[1]}#g" ${etcdConfig}
                sed -i "s#%node3_ip%#${server_arrays[2]}#g" ${etcdConfig}
                sed -i "s#%node4_ip%#${server_arrays[3]}#g" ${etcdConfig}
                sed -i "s#%node5_ip%#${server_arrays[4]}#g" ${etcdConfig}
                sed -i "s#%node5%#${nodeName}#g" ${etcdConfig}
                #sed -i '/ssl/d' ${etcdConfig}
                sed -i 's/https/http/g' ${etcdConfig}
            else
                printWarning "节点必须为3个节点或者5个节点"
                exit 0
            fi
        else
            echo "${etcdConfig}下已存在etcd.conf"
            #sed -i '/ssl/d' ${etcdConfig}
            sed -i 's/https/http/g' ${etcdConfig}
            exit 5
        fi

    if [ ! -f ${etcdService}/${EtcdServiceName} ];then
        echo -e "开始拷贝etcd.service ${etcdService}/"
        cp ../service/etcd.service ${etcdService}/
        sed -i -r "s#(WorkingDirectory=)(.*)#\1${etcdDataPath}#g" ${etcdService}/${EtcdServiceName}
        sed -i -r "s#(EnvironmentFile=-)(.*)#\1${etcdConfig}#g" ${etcdService}/${EtcdServiceName}
    else
        echo "${etcdService}下已存在${EtcdServiceName}"
        exit 11
    fi
        startEtcdService
;;

I)
	# systemctl daemon-reload etcd.service
	systemctl enable etcd.service
	systemctl start etcd.service
;;

i)
	systemctl stop etcd.service
;;

h)
	etcdClusterScriptCommandHelpInfo
;;

H)
	etcdClusterScriptCommandHelpInfo
;;

-help)
	etcdClusterScriptCofmandHelpInfo
;;

\?)
	etcdClusterScriptCommandHelpInfo
;;

esac
done
