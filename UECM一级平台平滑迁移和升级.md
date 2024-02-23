## UECM一级平台平滑迁移和升级

#### 简介
本文档描述了一级平台的平滑迁移和升级过程。现有的一级平台运行在6台物理机上，使用旧版本的中间件和微服务；新一级平台则运行在虚拟机上，采用了新版本的中间件和微服务。目标是将新一级平台平滑迁移到6台物理机上。

#### 现状分析
一级平台部署情况：

旧一级平台：6台物理机，旧版本中间件和微服务
新一级平台：虚拟机，新版本中间件和微服务

#### 备份
在一级平台的平滑迁移和升级过程中，为了确保数据的高可用性和业务连续性，我们采用了一种灵活而强大的灾备方案，以确保数据的安全和可用性。

我们实施了手动即时备份的方法，通过备份控制台（backup-ctl）手动即时备份 TiDB 数据库，并将生成的备份文件存储在全局 PVC 文件湖的指定目录中。这些备份以 .tar.gz 格式的文件形式保存。
```sh
# 在虚拟机1上执行以下命令，安装 backup-ctl 以开启本地定时自动备份
helm install backup-ctl http://helm.iottepa.cn:32021/charts/uap-backup-ctl-6.5.2-20231108-1832.tgz -n uap \
    --set-string common.env.ENV_EXPIRED_DAYS=7 \
    --set-string common.env.ENV_GLUSTERFS_NODE_VIP="虚拟IP" \
    --set-string common.env.ENV_GLUSTERFS_NODE_IPS="虚拟机1的IP地址\,虚拟机2的IP地址\,虚拟机3的IP地址" \
    --set-string common.env.ENV_GLUSTERFS_NODE_HOSTNAMES="虚拟机1的主机名\,虚拟机2的主机名\,虚拟机3的主机名" \
    --set-string common.nodeSelectorValue=1

# 给 TiDB 打补丁，启用备份/恢复的能力
kubectl exec -it deployment/backup-ctl -n uap -- /tidb-ctl.sh patch-tidb-for-br

# 查询已有的备份文件
kubectl exec -it deployment/backup-ctl -n uap -- /tidb-ctl.sh ls-tar

# 备份并导出为压缩包
kubectl exec -it deployment/backup-ctl -n uap -- /tidb-ctl.sh backup-and-save

# 查看全局 PVC 文件湖中的备份文件
# 新建临时目录
mkdir uap-global
# 挂载全局 PVC 文件湖到临时目录
mount -t glusterfs localhost:uap-global uap-global
# 查看备份文件，文件名形如 tidb-backup-20231109.tar.gz
ls uap-global/backup
```

#### 异常回退
升级可能失败是因为新版本的微服务存在代码 bug 或其他问题，此时需要进行回滚到旧版本的微服务。回滚的流程分为两部分：代码回滚和数据回滚。

代码回滚
无论是旧版本还是新版本的微服务，都是以不可变的 Docker 镜像运行的，因此升级失败时，只需回退到旧版本的 Docker 镜像即可。这利用了 Docker 容器化和 Kubernetes 云原生的特性。

数据回滚
数据回滚则是通过备份控制台（backup-ctl）手动恢复 TiDB 数据库。

```sh
# 检查历史备份是否存在
kubectl exec -it deployment/backup-ctl -n uap -- /tidb-ctl.sh ls-backup

# 如果存在历史备份，删除历史解压目录和历史恢复进度，请替换--name参数为特定日期
kubectl exec -it deployment/backup-ctl -n uap -- /tidb-ctl.sh rm-backup --name=tidb-backup-20231109

# 加载备份文件，请替换--name参数为特定日期
kubectl exec -it deployment/backup-ctl -n uap -- /tidb-ctl.sh load --name=tidb-backup-20231109

# 恢复历史数据，请替换--name参数为特定日期
kubectl exec -it deployment/backup-ctl -n uap -- /tidb-ctl.sh restore --name=tidb-backup-20231109

# 检查恢复进度，STATUS列为 Complete 表示恢复完毕，然后修改 TiDB 的 root 密码和时区
kubectl get restores.pingcap.com -n iottepa
# 等待直到 STATUS 列变为 Complete

# 初始化 TiDB 的 SQL，因为 TiDB 用户密码和时区设置不会被自动恢复
cat > init-tidb.sql <<'EOF'
CREATE USER if not EXISTS 'wacos'@'%' IDENTIFIED BY 'Uz7$kFp@X9!jGq$5vB';
GRANT ALL ON wacos.* TO 'wacos'@'%';
SET PASSWORD='WDUu9z48'; SET GLOBAL time_zone='+8:00'; flush privileges;
EOF

# 复制到 Pod
kubectl cp init-tidb.sql debug-mysql-client:/tmp/init-tidb.sql -n iottepa

# 执行 SQL 设置 TiDB 用户密码和时区
kubectl exec -it debug-mysql-client -n iottepa -- /bin/sh -ec "mysql -h mysql.iottepa -P 3306 -uroot </tmp/init-tidb.sql"
```

#### 总体步骤
1、卸载旧一级平台的k8s集群
在6台物理机上执行集群卸载操作，清理旧的k8s集群环境。
```sh
# 在6台物理机上执行以下操作：
# 1. 卸载 K3s 进程，忽略卸载过程中的报错信息
/usr/local/bin/k3s-uninstall.sh 

# 2. 卸载 K3s Agent 进程，忽略卸载过程中的报错信息
/usr/local/bin/k3s-agent-uninstall.sh 

# 3. 停止所有正在运行的 Docker 容器
docker stop $(docker ps -qa) 

# 4. 删除所有已停止的 Docker 容器
docker rm $(docker ps -qa) 
```

2、配置主机名
2.1、修改主机名：确保9台宿主机的主机名不冲突。
```sh
# 在6台物理机上执行以下操作：
# 使用 hostnamectl 命令修改主机名，请在 "<新主机名>" 处替换为新的主机名
# 确保这6台物理机都有不同的名称，并且不会和其他3台虚拟机的名字重复
hostnamectl set-hostname <新主机名>
```

2.2、修改/etc/hosts：确保9台宿主机能够相互识别主机名。
```sh
# 在这9台宿主机上执行以下操作：
# 使用 cat 命令向 /etc/hosts 文件追加对应虚拟机和物理机的 IP 地址和主机名
# 在实际操作中，请将 <虚拟机x的ip> 和 <物理机x的ip> 替换为实际的 IP 地址
# 另外请将 <虚拟机x的主机名> <物理机x的主机名> 替换为实际的主机名
cat >> /etc/hosts <<EOF
<虚拟机1的IP地址>    <虚拟机1的主机名>
<虚拟机2的IP地址>    <虚拟机2的主机名>
<虚拟机3的IP地址>    <虚拟机3的主机名>
<物理机1的IP地址>    <物理机1的主机名>
<物理机2的IP地址>    <物理机2的主机名>
<物理机3的IP地址>    <物理机3的主机名>
<物理机4的IP地址>    <物理机4的主机名>
<物理机5的IP地址>    <物理机5的主机名>
<物理机6的IP地址>    <物理机6的主机名>
EOF
```

3、扩容新一级平台的k8s集群
3.1、etcd集群扩容：将etcd集群扩展至9节点，需要注意的是，etcd集群的所有节点都是平等的，没有主从之分。
```sh
# 在虚拟机1上执行以下命令，为6台物理机生成对应的 etcd.service 文件，并将文件拷贝到各个物理机，然后启动 etcd

# 定义新的 etcd 节点列表
newEtcdNodes=("物理机1的主机名" "物理机2的主机名" "物理机3的主机名" "物理机4的主机名" "物理机5的主机名" "物理机6的主机名")

# 循环处理每个新的 etcd 节点
for newEtcdNode in ${newEtcdNodes[@]}
do
    # 获取每个新节点的 IP 地址
    newEtcdIp=$(grep $newEtcdNode /etc/hosts | awk '{print $1}')

    # 生成 etcd.service 文件，内容包含节点的配置信息
    cat > etcd.service.$newEtcdNode <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \
    --name $newEtcdNode \
    --data-dir /mnt/disks/etcd \
    --initial-advertise-peer-urls http://$newEtcdIp:2380 \
    --listen-peer-urls http://0.0.0.0:2380 \
    --listen-client-urls http://0.0.0.0:2379 \
    --advertise-client-urls http://$newEtcdIp:2379 \
    --initial-cluster-token etcd-cluster-token-e3b0c44298fc \
    --initial-cluster etcd-node-1=http://<虚拟机1的IP地址>:2380,etcd-node-2=http://<虚拟机2的IP地址>:2380,etcd-node-3=http://<虚拟机3的IP地址>:2380 \
    --initial-cluster-state existing
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
done

# 注意：每次只能扩容一个 etcd 节点，确保前一个节点添加成功后，再添加后一个节点
# 在虚拟机1上执行以下命令，添加新的物理机到 etcd 集群
ETCDCTL_API=3 etcdctl member add 物理机x的主机名 --peer-urls=http://物理机x的IP地址:2380

# 将 etcd.service 文件复制到相应的物理机上
scp -P2222 etcd.service.物理机x的主机名 root@物理机x的IP地址:/usr/lib/systemd/system/etcd.service

# 在物理机x上执行以下命令，启用并启动 etcd
systemctl enable etcd
systemctl start etcd
```

3.2、k8s集群扩容：将k8s集群扩展至9节点，其中前3台物理机是主节点，后3台物理机是从节点。
```sh
# 在前3台物理机上执行以下步骤：
# 1. 导入K3s镜像到Docker中
docker load -i /opt/k3s/image/k3s-ecology-customized-airgap-images.tar
docker load -i /opt/k3s/image/k3s-ecology-vendor-airgap-images.tar

# 2. 准备K3s所需的文件和配置
mkdir -p /var/lib/rancher/k3s/agent/images/
cp /opt/k3s/vendor/k3s-airgap-images-amd64.tar /var/lib/rancher/k3s/agent/images/
cp /opt/k3s/vendor/k3s /usr/local/bin/k3s
chmod +x /usr/local/bin/k3s
cat > /etc/profile.d/k3s.sh <<EOF
#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
EOF
source /etc/profile.d/k3s.sh

# 3. 配置K3s节点的连接信息及启动K3s
export INSTALL_K3S_SKIP_DOWNLOAD=true
export K3S_URL= # 请将其赋空值
export K3S_TOKEN= # 请将其赋空值
export K3S_DATASTORE_ENDPOINT=http://虚拟机1的IP地址:2380,http://虚拟机2的IP地址:2380,http://虚拟机3的IP地址:2380
export INSTALL_K3S_EXEC="--node-name 物理机x的主机名 --disable servicelb --disable traefik --disable local-storage --https-listen-port 10443 --kube-apiserver-arg service-node-port-range=1-65535 --docker"
sh /opt/k3s/vendor/install-k3s.sh

# 在虚拟机1上执行以下命令，查看主节点token，后续命令中会用到，注意替换这个变量
cat /var/lib/rancher/k3s/server/token

# 在后3台物理机上执行以下步骤：
# 1. 导入K3s镜像到Docker中
docker load -i /opt/k3s/image/k3s-ecology-customized-airgap-images.tar
docker load -i /opt/k3s/image/k3s-ecology-vendor-airgap-images.tar

# 2. 准备K3s所需的文件和配置
mkdir -p /var/lib/rancher/k3s/agent/images/
cp /opt/k3s/vendor/k3s-airgap-images-amd64.tar /var/lib/rancher/k3s/agent/images/
cp /opt/k3s/vendor/k3s /usr/local/bin/k3s
chmod +x /usr/local/bin/k3s
cat > /etc/profile.d/k3s.sh <<EOF
#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
EOF
source /etc/profile.d/k3s.sh

# 3. 配置K3s节点的连接信息及启动K3s
export INSTALL_K3S_SKIP_DOWNLOAD=true
export K3S_URL="https://虚拟机1的IP地址:10443"
export K3S_TOKEN=主节点token # 注意替换这个变量
export K3S_DATASTORE_ENDPOINT= # 请将其赋空值
export INSTALL_K3S_EXEC="--docker"
sh /opt/k3s/vendor/install-k3s.sh
```

4、Pod平滑迁移和升级
驱逐中间件Pod：迁移新一级平台中间件Pod至6台物理机。
驱逐微服务Pod：迁移新一级平台微服务Pod至6台物理机。

kubectl drain 命令用于将 Kubernetes 集群中的节点设置为不可调度状态，并且驱逐节点上的 Pod。这个命令通常在需要对节点进行维护、升级或者移除时使用。在执行这个命令之前，通常会提前确保节点上的 Pod 被安全地迁移到其他节点上，以避免服务中断或数据丢失。

drain 命令参数说明：
--force: 强制执行驱逐操作。
--delete-local-data: 即使有使用 emptyDir 存储的 Pod 也会继续执行驱逐操作。
--ignore-daemonsets: 忽略 DaemonSet 管理的 Pod，以确保不会删除这些 Pod。

```sh
# 注意：逐一驱逐节点，确保每次只驱逐一个虚拟机节点。在开始驱逐下一个节点之前，请确认前一个节点已经完全被驱逐
# 以下步骤在任意一个物理机上执行：
# 驱逐虚拟机1节点
kubectl drain 虚拟机1的节点名 --force --delete-local-data --ignore-daemonsets
# 驱逐虚拟机2节点
kubectl drain 虚拟机2的节点名 --force --delete-local-data --ignore-daemonsets
# 驱逐虚拟机3节点
kubectl drain 虚拟机3的节点名 --force --delete-local-data --ignore-daemonsets
```

5、缩容新一级平台的k8s集群
3.1、etcd集群缩容：将etcd集群缩容至3节点，从集群中删除虚拟机节点，确保集群中仅包含6台物理机节点。
```sh
# 以下步骤在任意一个物理机上执行：
# 查看当前 etcd 集群成员列表，获取要删除的虚拟机节点的成员ID
ETCDCTL_API=3 etcdctl member list

# 从 etcd 集群中删除指定成员（虚拟机节点）
ETCDCTL_API=3 etcdctl member remove 虚拟机节点x的成员ID

# 检查 etcd 集群状态，确认节点已经被移除
ETCDCTL_API=3 etcdctl member list
```

3.2、k8s集群缩容：将k8s集群缩容至6节点，从集群中删除虚拟机节点，确保集群中仅包含6台物理机节点。
```sh
# 查看当前 Kubernetes 集群中的所有节点列表，获取要删除的虚拟机节点名
kubectl get node

# 使用 kubectl 删除不再需要的虚拟机节点
kubectl delete node 虚拟机节点x的成员ID

# 再次检查 Kubernetes 集群的状态，确认节点已经成功地被移除
kubectl get node
```

6、迁移keepalived的虚拟IP
将keepalived的虚拟IP迁移到6台物理机，确保服务的高可用性。
```sh
# 在前 3 台物理机执行以下命令
cat > /etc/keepalived/keepalived.conf <<EOF
# 注意：仅需更改三处内容：virtual_router_id、priority 和 virtual_ipaddress
# 注意：virtual_router_id 是 VRRP 组名，确保同一集群所有节点设置相同，不同集群需设置不同的组名。
# 注意：priority 是优先级设置，确保同一集群所有节点的优先级不同。例如，节点 1 设置为 100，节点 2 设置为 90，节点 3 设置为 80。
# 注意：virtual_ipaddress 是虚拟 IP 地址，要确保所有节点设置的虚拟 IP 地址都相同，并且不与其他现有 IP 地址发生冲突。
vrrp_instance VI_1 {
    state BACKUP # 所有节点都配置为备用（BACKUP），非抢占模式
    interface LAN1 # 绑定虚拟 IP 的网卡接口
    virtual_router_id <VRRP 组名,可以取自虚拟 IP 的最后一段> # VRRP 组名范围：0 到 255，请避免使用这两个边界值。
    priority <优先级> # 优先级设置，确保所有节点的优先级不同。例如，节点 1 设置为 100，节点 2 设置为 90，节点 3 设置为 80。
    advert_int 1 # 组播信息发送间隔，确保所有节点设置一样。
    nopreempt # 避免不必要的主备切换，所有节点都要设置。
    authentication { # 设置密码验证信息，确保所有节点设置一样。
        auth_type PASS
        auth_pass wanwoo
    }
    virtual_ipaddress {
        <虚拟 IP>  # 指定虚拟 IP，确保所有节点设置相同。例如 172.18.5.224
    }
}
EOF

# 启动 Keepalived
systemctl start keepalived
# 设置 Keepalived 为开机自启动
systemctl enable keepalived
```

#### 结论
完成一级平台的平滑迁移和升级后，系统将运行在6台物理机上，并使用新版本的中间件和微服务。

#### 风险评估和风险管理
注意：

实施过程中，确保备份重要数据，并进行验证，避免数据丢失或服务中断。
严格遵循操作规程和安全措施，以确保操作的准确性和安全性。

#### 实施计划
以上技术方案文档提供了参考和指导，具体实施时可以结合实际情况进行调整和拓展。
