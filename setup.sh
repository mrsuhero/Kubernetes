#!/bin/bash
#--------------------------------------------
#����ʵ�ּ�Ⱥ�������Զ�����ű�
#author: wang_yzhou
#date: 20170726
#˵����������centos7ϵͳ
#--------------------------------------------
echo "��ʼ���м�Ⱥ�İ�װ"
sleep 5
echo "3���ʼ��װ......"
sleep 3
#�жϵ�ǰ�û��Ƿ�Ϊroot�û�
user=`whoami`
machinename=`uname -m`
if [ "$user" != "root" ]; then
    echo "����root��ִ�иýű�"
    exit 1
fi

#����������Դ
change_aliyum(){
#���wget�����Ƿ�װ
command -v wget >/dev/null 2>&1 || { echo >&2 "I require wget but it's not installed.  trying to get wget."; yum install -y wget; }
#����������Դ
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum makecache
}

#�رշ���ǽ
close_firewall(){
systemctl stop firewalld
systemctl disable firewalld
}
#��װmaster���
install_master_module(){
echo "��ȷ����ǰ����û�а�װdocker,etcd,kubernetes"
read -p "input (y/n):" yn
[ "$yn" == "Y" ] || [ "$yn" == "y" ]&& echo "ok,continue"&& yum install -y etcd docker-ce kubernetes
[ "$yn" == "N" ] || [ "$yn" == "n" ]&& echo "������ɸɾ�ж�غ������б��ű�" && exit 1
}

#�޸�etcd�����ļ�
update_etcd_conf(){
echo "ETCD_NAME=default
ETCD_DATA_DIR=\"/var/lib/etcd/default.etcd\"
ETCD_LISTEN_CLIENT_URLS=\"http://0.0.0.0:2379\"
ETCD_ADVERTISE_CLIENT_URLS=\"http://localhost:2379\"">/etc/etcd/etcd.conf
}

#�޸�apiserver�����ļ�
update_apiserver_conf(){
echo "KUBE_API_ADDRESS=\"--address=0.0.0.0\"
KUBE_API_PORT=\"--port=8080\"
KUBELET_PORT=\"--kubelet_port=10250\"
KUBE_ETCD_SERVERS=\"--etcd_servers=http://127.0.0.1:2379\"
KUBE_SERVICE_ADDRESSES=\"--service-cluster-ip-range=10.254.0.0/16\"
KUBE_ADMISSION_CONTROL=\"--admission_control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota\"
KUBE_API_ARGS=\"\"">/etc/kubernetes/apiserver
}

#�޸�kubernetes�����ļ�
update_kube_conf(){
read -p "����master�ڵ��ip��ַ:" ip
echo "KUBE_LOGTOSTDERR=\"--logtostderr=true\"
KUBE_LOG_LEVEL=\"--v=0\"
KUBE_ALLOW_PRIV=\"--allow-privileged=false\"
KUBE_MASTER=\"--master=http://$ip:8080\"">/etc/kubernetes/config
}

#����master�ڵ����ط���
up_master_service(){
for SERVICES  in etcd docker kube-apiserver kube-controller-manager kube-scheduler;  do
    systemctl restart $SERVICES
    systemctl enable $SERVICES
    systemctl status $SERVICES -l
done
}

#���etcd��������
add_etcd_net(){
etcdctl mk /atomic.io/network/config '{"Network":"172.17.0.0/16"}'
}

#��⼯Ⱥ�Ƿ�װ�ɹ�
check_cluster_status(){
kubectl get nodes
}

#��װnode�ڵ����
install_node_module(){
echo "��ȷ����ǰ����û�а�װflannel,docker,kubernetes"
read -p "input (y/n):" yn
[ "$yn" == "Y" ] || [ "$yn" == "y" ]&& echo "ok,continue"&& yum install -y flannel docker-ce kubernetes
[ "$yn" == "N" ] || [ "$yn" == "n" ]&& echo "������ɸɾ�ж�غ������б��ű�" && exit 1
}

#����flanneld
update_flanneld_conf(){
read -p "����master�ڵ��ip��ַ:" ip
echo "FLANNEL_ETCD=\"http://$ip:2379\"
FLANNEL_ETCD_ENDPOINTS=\"http://$ip:2379\"
FLANNEL_ETCD_PREFIX=\"/atomic.io/network\"">/etc/sysconfig/flanneld
}

#����kubelet
update_kubelet_conf(){
read -p "����master�ڵ��ip��ַ��" master
read -p "���뵱ǰnode�ڵ��ip��ַ��" node
read -p "����pause����Ĳֿ��ַ��" image
echo "KUBELET_ADDRESS=\"--address=0.0.0.0\"
KUBELET_PORT=\"--port=10250\"
KUBELET_HOSTNAME=\"--hostname-override=$node\"
KUBELET_API_SERVER=\"--api-servers=http://$master:8080\"
KUBELET_POD_INFRA_CONTAINER=\"--pod-infra-container-image=suhero/k8s-gcr-io-pause\"
KUBELET_ARGS=\"--cluster-dns=10.254.0.100 --cluster-domain=cluster.local\"">/etc/kubernetes/kubelet
}

#����node�ڵ���ط���
up_node_service(){
for SERVICES in kube-proxy kubelet docker flanneld; do
    systemctl restart $SERVICES
    systemctl enable $SERVICES
    systemctl status $SERVICES 
done
}

#�ű����
echo -n "ѡ��Ҫ��װ�Ľ�ɫ��master������node��(�ϸ��Сд)��"
read answer
if [ "$answer" == master ];then
  
  change_aliyum
  close_firewall
  install_master_module
  update_etcd_conf
  update_apiserver_conf
  update_kube_conf
  up_master_service
  add_etcd_net

elif [ "$answer" == node ];then

  change_aliyum
  close_firewall
  install_node_module
  update_flanneld_conf
  update_kube_conf
  update_kubelet_conf
  up_node_service

fi