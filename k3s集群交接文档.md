# k3s集群交接文档

### 现网k3s集群现状
**部署模式**：平安现网部署了1个一级平台（3+3高可用模式），40多个二级平台（3+0高可用模式），其中，3+3指的是3个主节点+3个工作节点，3+0指的是3个主节点+0个工作节点，因底层原理，底层部署方式相同，统称为3+n模式。

**k3s集群版本**：
|组件|依赖|端口|版本|宿主机安装|类型|systemd配置文件|
|----|----|----|----|----|----|----|
|docker|无|-|20.10.12|是|后台服务|/usr/lib/systemd/system/docker.service|
|k3s主节点|etcd|绑定宿主机10443端口，用于kubectl，或helm，或Lens访问等|v1.19.3+k3s-ba43d268|是|后台服务|/etc/systemd/system/k3s.service|
|k3s工作节点|k3s主节点|-|v1.19.3+k3s-ba43d268|是|后台服务|/etc/systemd/system/k3s-agent.service|
|kubectl|无|-|v1.19.3+k3s-ba43d268|是|命令行工具|无|
|etcd|无|绑定宿主机2379端口，用于外部访问，绑定宿主机2380端口，用于peer内部通讯|3.3.14|是|后台服务|/usr/lib/systemd/system/etcd-0.service|
|etcdctl|无|-|3.3.14|是|命令行工具|无|
|glusterfs|无|-|9.4|是|后台服务|/usr/local/lib/systemd/system/glusterd.service|
|keepalived|无|-|v2.0.20|是|后台服务|/usr/lib/systemd/system/keepalived.service|
|helm|无|-|v3.8.0|是|命令行工具|无|

**k3s基础生态组件版本**：
|组件|依赖|端口|helm包版本|上游官方版本|用途|k3s命名空间|
|----|----|----|----|----|----|----|
|uap-local-path-provisioner|无|-|0.0.24-6.0.0-20230704|0.0.24|自己封装的Local Path Provisioner离线包，安装后提供了名为local-path的k8s存储类，自动生成pv并绑定pvc，数据落盘到宿主机本地，基于rancher的local-path-provisioner|kube-system|
|uap-docker-registry|无|通过NodePort的方式，绑定宿主机32011端口|2.8.0-20230519|2.8.0|自己封装的docker私仓离线包|default|
|uap-helm-registry|无|通过NodePort的方式，绑定宿主机32021端口|0.14.0-20230519|0.14.0|自己封装的helm私仓离线包|default|
|uap-package-updater|无|通过NodePort的方式，绑定宿主机31888端口|1.0.1|无|离线包上传模块，改自uecm的system-core模块|default|
|uap-ntp-server|无|-|3.5.0-20230807-1127|3.5.0|自己封装的ntp离线包，自动对齐k3s集群节点的系统时间|default|
|k8s-key-server|无|-|2.0.0|无|封装了k3s访问密钥的nginx，用于helm包的前置依赖等待机制（例如nacos等待tidb，微服务等待kafka）|default|
|k8s-node-local-dns|无|-|2.0.0|无|封装了NodeLocal DNSCache，用于加速CoreDNS|default|
|glusterfs-positioner|无|-|1.0.0|无|封装了名为glusterfs-positioner的Service，以及对应的底层Endpoints，通过endpoints.addresses参数设置虚ip，用于k3s集群访问glusterfs（tidb备份恢复需借助网络文件系统）|iottepa|
|glusterfs-positioner|无|-|1.0.0|无|封装了名为glusterfs-positioner的Service，以及对应的底层Endpoints，通过endpoints.addresses参数设置虚ip，用于k3s集群访问glusterfs（uap微服务需借助网络文件系统传文件）|uap|

**中间件版本**：
|组件|依赖|端口|helm包版本|上游官方版本|用途|k3s命名空间|
|----|----|----|----|----|----|----|
|uap-tidb-operator|无|-|v1.4.4|v1.4.4|自己封装的tidb自动化运维离线包|iottepa|
|uap-tidb|uap-tidb-operator|-|6.5.2-20230816|6.5.2|自己封装的tidb数据库离线包|iottepa|
|uap-kafka|无|通过NodePort的方式，绑定宿主机31001端口|3.3.1-20230616|3.3.1|自己封装的kafka离线包|iottepa|
|uap-redis-cluster|无|-|7.0.11-20230816|7.0.11|自己封装的redis离线包|iottepa|
|uap-nacos-cluster|uap-tidb|-|v2.2.3-20230814|v2.2.3|自己封装的nacos离线包|iottepa|
|uap-nginx|无|通过设置hostNetwork的DaemonSet的方式，根据nginx配置动态绑定宿主机的任意端口（例如80、443、7443、7888、9443、19722、31000）|1.25.0-20230831-1108|1.25.0|自己封装的nginx离线包|uap|

### 公司内网k3s集群现状
除了可能部署到虚拟机之外，和现网k3s集群现状一致。另外注意预研环境和现网不一致，因为预研环境可能手动修改了某些组件（例如kafka预研环境）。

### k3s集群运维
**一键安装k3s集群**：使用deploy_uap脚本一键部署k3s集群，支持1+0单机模式，3+0模式，3+3模式。此脚本没有预置到iso镜像，需手动上传到宿主机，git仓库地址 http://gitlab.iottepa.cn/fzgang/system/project_deploy_script

**一键卸载k3s集群**：在宿主机的所有节点执行/opt/k3s/utils/remove-k3s.sh一键卸载k3s集群，此脚本已预置到iso镜像中。
```sh
sh /opt/k3s/utils/remove-k3s.sh
```

**更新k3s集群的ssl证书**：k3s集群的ssl证书默认一年到期，每次启动k3s时都会检查ssl证书的到期时间，如果已过期，或临近过期（3个月），则自动更新ssl证书。所以只需重启k3s进程即可自动更新ssl证书，注意重启k3s进程不影响业务，pod正常运行，docker容器正常运行。另外，重装k3s集群后，ssl证书也重新生成。官方文档 https://docs.k3s.io/zh/cli/certificate
```sh
systemctl restart k3s # 在所有k3s主节点执行
systemctl restart k3s-agent # 在所有k3s工作节点执行
```

**修改节点ip**：git仓库地址 http://gitlab.iottepa.cn/java/helm-charts/-/blob/main/UAP%E9%9B%86%E7%BE%A4%E6%94%B9IP%E6%AD%A5%E9%AA%A4.md

**替换节点物理机**：因磁盘等问题替换节点物理机，git仓库地址 http://gitlab.iottepa.cn/java/helm-charts/-/blob/main/UAP%E9%9B%86%E7%BE%A4%E6%9B%BF%E6%8D%A2%E4%B8%BB%E8%8A%82%E7%82%B9(3%E8%8A%82%E7%82%B9).md

**tidb数据恢复**：git仓库地址 http://gitlab.iottepa.cn/midware/backup-ctl/-/blob/main/README.md

**排查节点的磁盘压力**：一般都是loki占用了大量磁盘空间导致，例如占了100G以上。另外，公司内网k3s集群偶现kafka占用了大量磁盘空间，原因可能是虚拟机分配的磁盘容量太小（分配了300G，一般分配500G）。
```sh
du --max-depth=1 --human-readable / # 排查根目录下的子目录的磁盘占用情况
du --max-depth=1 --human-readable /mnt # 进一步排查/mnt目录下的子目录的磁盘占用情况
df --human-readable # 看磁盘占用空间百分比
lsblk # 看磁盘总大小
```

### rfid的k3s集群运维（和UAP不相关，但现网rfid也需维护，特此注明）

现网rfid部署了1+0单机版k3s集群，和uecm版本的中间件。注意，现网rfid用的tidb版本和uap并不一致，因此tidb备份恢复的步骤也不一致。现网rfid已部署了uecm版的tidb自动备份机制，并且成功恢复过客户误删除的tidb数据。

**rfid的tidb数据恢复**：git仓库地址 http://gitlab.iottepa.cn/java/helm-charts/-/blob/main/rfid%E6%95%B0%E6%8D%AE%E6%81%A2%E5%A4%8D.md

**rfid物理机重启后，系统不能自动恢复**：原因是1+0单机版k3s集群，底层的glusterfs也是单机版，glusterfs的单机版不如集群版稳定，经常出现物理机重启后，glusterfs服务虽能正常启动，但是glusterfs volume却启动失败，导致rfid中间件和微服务不能读写glusterfs，因此不能自动恢复。物理机重启后，如果系统不能自动恢复，手动重启glusterfs服务即可恢复。

同理，公司内网的1+0单机版k3s集群（例如demo演示环境），也会遇到同样的问题，解决方法也一样。

公司内网或现网3+0或3+3环境无此问题。

```sh
# 手动重启glusterfs服务
systemctl restart glusterd
```

### k3s集群未来展望
1、kafka因平安现网防火墙端口问题，只能使用单副本，目前现网kafka用的存储层是hostpath，也即落盘到kafka pod所在的宿主机磁盘。kafka pod部署在节点1，kafka数据也就落盘到节点1，这造成了kafka不能实现高可用，节点1磁盘损坏后，kafka数据就丢失了。已经预研了kafka+glusterfs，kafka+openebs，strimzi+openebs这三种方案，前两种因kafka服务端报错而放弃，最后一种（strimzi是cncf推荐的kafka封装版）仍在验证中，目前看较为稳定。

2、建议用openebs替换glusterfs，因为glusterfs不适用于kafka，读写效率较低，而且需要在宿主机安装glusterfs服务，最重要的一点是：高版本k8s，以及高版本k3s已经删除了glusterfs的内置支持。openebs只需在宿主机安装标准的iSCSI客户端，openebs服务以pod形式托管在k8s集群，容易管理。另外，预研kafka时，已封装了openebs的离线包，git仓库地址 http://gitlab.iottepa.cn/midware/openebs-jiva-provisioner

3、升级k3s版本时，注意检查存储层（glusterfs或openebs）兼容性，中间件（特别是uap-tidb-operator）兼容性，以及etcd兼容性，某些组件可能依赖了特定版本的k8s接口。

### k3s集群涉及的git仓库
|名称|用途|地址|
|----|----|----|
|kylin_project_script|预置k3s物料到iso镜像|git@git.iottepa.com:yujie/kylin_project_script.git|
|project_deploy_script|uap脚本，包括deploy_uap脚本（用于一键部署k3s集群）|http://gitlab.iottepa.cn/fzgang/system/project_deploy_script|
|helm-charts|uecm的helm包和文档，注意uap的文档也放这个仓库了|http://gitlab.iottepa.cn/java/helm-charts|
|docker-images|uecm的docker镜像，已弃用，uap的docker镜像和helm包已按CI标准，封装为离线包，放到独立的仓库|http://gitlab.iottepa.cn/java/docker-images|
|docker私仓|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/docker-registry|
|helm私仓|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/helm-registry|
|离线包上传模块|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/package-updater|
|ntp服务|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/ntp-server|
|本地卷供应器|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/local-path-provisioner|
|openebs的jiva卷供应器|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/openebs-jiva-provisioner|
|tidb自动化运维|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/tidb-operator|
|tidb数据库|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/tidb|
|tidb备份恢复|封装为符合CI标准的离线包，已弃用，使用重构的backup-ctl|http://gitlab.iottepa.cn/midware/tidb-ctl|
|tidb备份恢复|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/backup-ctl|
|kafka单副本版|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/kafka|
|kafka集群版|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/kafka-cluster|
|kafka单副本版|封装为符合CI标准的离线包，已弃用，这是预研kafka+glusterfs用的|http://gitlab.iottepa.cn/midware/kafka-standalone|
|kafka命令行工具|封装为符合CI标准的离线包，封装了kcat|http://gitlab.iottepa.cn/midware/kafka-cli|
|kafka管理界面|封装为符合CI标准的离线包，封装了lenses|http://gitlab.iottepa.cn/midware/kafka-ui|
|kafka单副本版|封装为符合CI标准的离线包，这是青春版用的，borker和controller融合为1个pod|http://gitlab.iottepa.cn/midware/kafka-babel|
|redis单副本版|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/redis|
|redis集群版|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/redis-cluster|
|nginx|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/nginx|
|nacos单副本版|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/nacos|
|nacos集群版|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/nacos-cluster|
|loki集中式日志|封装为符合CI标准的离线包|http://gitlab.iottepa.cn/midware/loki|

### kubectl常用命令
```sh
# 列出k3s集群节点，并显示更多字段（例如宿主机ip等）
kubectl get node -o wide

# 列出k3s集群节点，并显示节点标签
kubectl get node --show-labels

# 给指定节点打标签
kubectl label node k3s-node-1 iottepa.cn/node-id=1
kubectl label node k3s-node-2 iottepa.cn/node-id=2
kubectl label node k3s-node-3 iottepa.cn/node-id=3

# 删除指定节点的标签
kubectl label node k3s-node-1 iottepa.cn/node-id-
kubectl label node k3s-node-2 iottepa.cn/node-id-
kubectl label node k3s-node-3 iottepa.cn/node-id-

# 列出iottepa空间的pod，并显示更多字段（例如分配到哪个节点等）
kubectl get pod -n iottepa -o wide

# 删除iottepa空间的名为nacos-0的pod
kubectl delete pod nacos-0 -n iottepa

# 强制删除iottepa空间的名为nacos-0的pod
kubectl delete pod nacos-0 -n iottepa --grace-period=0 --force

# 查看iottepa空间的名为nacos-0的pod的日志
kubectl logs nacos-0 -n iottepa

# 查看iottepa空间的名为nacos-0的pod的日志，并滚动刷新
kubectl logs nacos-0 -n iottepa -f

# 查看uap空间的指定pod，并返回yaml格式的pod详情
kubectl get pod core-config-54db9fc4df-5ztp6 -n uap -o yaml

# 查看uap空间的指定pod，翻页到最下面，Events中有pod报错原因（例如镜像下载失败，pvc绑定失败，节点不能调度等）
kubectl describe pod core-config-54db9fc4df-5ztp6 -n uap

# 热加载nginx配置文件
kubectl get pod -l app=nginx -o name -n uap | xargs -I{} kubectl exec -it {} -n uap -- sh -c "nginx -s reload"

# 冷加载nginx配置文件
kubectl get pod -l app=nginx -o name -n uap | xargs -I{} kubectl delete {} -n uap

# uap微服务缩容到0
kubectl get deployment -n uap -o name | xargs -i{} kubectl scale --replicas=0 {} -n uap

# uap微服务恢复到3副本
kubectl get deployment -n uap -o name | xargs -i{} kubectl scale --replicas=3 {} -n uap

# 列出存储类，标记为(default)的是默认存储类，保持k3s集群只有一个默认的存储类，否则可能出现问题
kubectl get sc

# 设置local-path为默认的storageclass
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 取消设置local-path为默认
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# 设置openebs-jiva-csi-default为默认的storageclass
kubectl patch storageclass openebs-jiva-csi-default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 取消设置openebs-jiva-csi-default为默认
kubectl patch storageclass openebs-jiva-csi-default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# 列出iottepa空间的pvc，标记为Bound的表示绑定成功，VOLUME列是绑定的pv
kubectl get pvc -n iottepa

# 列出k3s集群所有的pv，CLAIM列是绑定的pvc
kubectl get pv

# 删除kafka的pvc，如果绑定pv的RECLAIM POLICY为Delete，自动级联删除绑定的pv
kubectl delete pvc data-kafka-0 data-kafka-controller-0 -n iottepa

# 删除指定的pv，也即删除落盘数据
kubectl delete pv pvc-99826377-0e40-4429-93c5-77d06b4c9aae pvc-cfce43d2-9dba-4e26-b3ee-1c98a7ef19a2
```

### helm常用命令
```sh
# 查看iottepa空间已安装的helm包（中间件或微服务）的release名称
helm list -n iottepa

# 根据release名称卸载iottepa空间已安装的kafka
helm delete kafka -n iottepa

# 安装kafka到iottepa空间，默认不开启免密的调试端口, 通过添加 --set brokerService.debug=true 参数开启免密的调试端口
helm install kafka http://helm.iottepa.cn:32021/charts/uap-kafka-{版本}.tgz -n iottepa --set brokerService.advertisedHost=<虚ip>

# 更新nacos访问tidb的密码，否则nacos无法正常使用，特别注意--reuse-values参数！！
helm upgrade nacos http://helm.iottepa.cn/charts/nacos-0.1.5.tgz \
    --namespace iottepa --reuse-values \
    --set-string nacos.storage.db.password='WDUu9z48'

# 列出default空间已安装的helm包
helm list

# 列出iottepa空间已安装的helm包
helm list -n iottepa

# 列出所有空间已安装的helm包
helm list -A

# 用本地路径安装helm包到default空间
helm install mysql-cli uap-mysql-cli-1.1.0.tgz

# 用本地路径安装helm包到default空间，并覆盖一个默认参数
helm install kafka uap-kafka-cluster-3.3.1-6.0.0-20230621.tgz --set brokerService.advertisedHost=172.18.5.16

# 删除（卸载）iottepa空间已安装的nacos
helm delete nacos -n iottepa

# 从私仓安装helm包到iottepa空间
helm install nacos-cluster http://helm.iottepa.cn:32021/charts/uap-nacos-cluster-1.4.2-20230531.tgz -n iottepa

# 删除（卸载）iottepa空间已安装的nacos-cluster
helm delete nacos-cluster -n iottepa

# 更新uap空间的glusterfs-positioner的一个参数，其他参数保持原状（注意--reuse-values参数不可缺少）
helm upgrade glusterfs-positioner /opt/k3s/helm/glusterfs-positioner-1.0.0.tgz --reuse-values --set endpoints.addresses[0]=172.18.5.16 -n uap

# 查看uap空间的glusterfs-positioner的所有覆盖的非默认的参数
helm get values glusterfs-positioner -n uap

# 查看uap空间的glusterfs-positioner的所有参数
helm get values glusterfs-positioner -n uap --all
```

### 封装为离线helm包

0、参考现有的某个已封装为符合CI标准的离线包的git仓库的目录结构，新增一个git仓库，例如kafka单副本版，git仓库地址 http://gitlab.iottepa.cn/midware/kafka
1、修改helm包源码和版本号，提交到自己的分支
2、执行一遍“中间件手动打包的流程”，验证修改正确无误
3、提交Merge requests到main分支
4、review并合并到main分支，触发CI自动打包（自动构建docker镜像和helm包）
5、登录“编译管理系统”并出包（详细步骤咨询CI负责人），地址http://172.18.5.190:8004/middlewares
6、登录Jenkins查看出包进度，地址http://172.18.5.190:8003/job/build-middleware/
7、在172.18.5.190宿主机的/ww/app/middlewares目录取包

```sh
test@DESKTOP-VDB22IC MINGW64 /f/midware/mysql-cli (main)
##
# 中间件仓库根目录的.gitlab-ci.yml文件触发了main分支的自动构建
##
$ cat .gitlab-ci.yml
include:
  - project: $CI_TEMPLATE_PATH
    ref: 'uap'
    file: '/uap/gitlab-ci-midware.yml'

##
# helm包的元数据（版本信息）
# appVersion是上游中间件的版本，一般不改动
# version是helm包的版本，格式：<上游版本号>-<UAP中间件自己的版本号,例6.0.0>-<时间,格式yyyyMMdd>，示例1.1.0-6.0.0-20230625
##
$ cat helm/Chart.yaml
apiVersion: v1
appVersion: 1.1.0 # 上游中间件的版本
name: uap-mysql-cli
description: mysql-cli
version: 1.1.0 # helm包的版本
```

### docker私仓的使用方法

如前所述，docker私仓通过NodePort的方式，绑定宿主机32011端口，而且k3s集群的所有节点都配置了/etc/hosts文件，docker.iottepa.cn指向了127.0.0.1本地。

```sh
# 查看docker私仓的hostname配置
# 127.0.0.1 docker.iottepa.cn
grep docker /etc/hosts

# 查看docker私仓中的镜像
curl http://docker.iottepa.cn:32011/v2/_catalog | jq .

# 查看docker私仓中的kafka的repo名称
# uap-kafka-kraft
curl http://docker.iottepa.cn:32011/v2/_catalog | jq . | grep kafka

# 根据repo名称查看版本
curl http://docker.iottepa.cn:32011/v2/uap-kafka-kraft/tags/list | jq .

# 从docker私仓下载docker镜像
docker pull docker.iottepa.cn:32011/uap-kafka-kraft:3.3.1

# 上传docker镜像到docker私仓
docker push docker.iottepa.cn:32011/uap-kafka-kraft:3.3.1
```

### helm私仓的使用方法

如前所述，helm私仓通过NodePort的方式，绑定宿主机32021端口，而且k3s集群的所有节点都配置了/etc/hosts文件，helm.iottepa.cn指向了127.0.0.1本地。

```sh
# 查看helm私仓中的helm包
curl http://helm.iottepa.cn:32021/api/charts | jq .

# 查看helm私仓中的kafka版本
# charts/uap-kafka-3.3.1-20230616.tgz
curl http://helm.iottepa.cn:32021/api/charts | jq . | grep kafka

# 查看版本详情
curl http://helm.iottepa.cn:32021/api/charts/uap-kafka/3.3.1-20230616 | jq .

# 从helm私仓下载kafka的helm包
curl -O http://helm.iottepa.cn:32021/charts/uap-kafka-3.3.1-20230616.tgz

# 解压helm包
# uap-kafka/Chart.yaml
# uap-kafka/values.yaml
# uap-kafka/templates/NOTES.txt
# uap-kafka/templates/broker-service.yaml
# uap-kafka/templates/broker-statefulset.yaml
# uap-kafka/templates/configmap.yaml
# uap-kafka/templates/controller-service.yaml
# uap-kafka/templates/controller-statefulset.yaml
# uap-kafka/templates/secret.yaml
tar zxvf uap-kafka-3.3.1-20230616.tgz

# 打包为helm包
# Successfully packaged chart and saved it to: /root/uap-kafka-3.3.1-20230616.tgz
helm package uap-kafka

# 上传helm包到helm私仓
curl --data-binary "@/root/uap-kafka-3.3.1-20230616.tgz" http://helm.iottepa.cn:32021/api/charts

# 删除指定版本的helm包
curl -X DELETE http://helm.iottepa.cn:32021/api/charts/uap-kafka/3.3.1-20230616
```

### glusterfs的使用方法

【示例1】宿主机中使用glusterfs的方法，以uap微服务使用的uap-global pvc为例说明如下：

glusterfs支持标准的mount指令，可以挂载到指定的目录，读写挂载后的目录就是读写glusterfs volume。另外，注意反挂载，避免误操作glusterfs volume。

```sh
# 查看peer状态
gluster peer status

# 查看volume列表
gluster volume list

# 查看指定的volume状态
gluster volume status uap-global

# 新建临时目录
mkdir -p /root/uap-global-volume

# 挂载指定的volume到临时目录
mount -t glusterfs 127.0.0.1:uap-global /root/uap-global-volume

# 查看指定volume的子目录
# /root/uap-global-volume/nginx-conf-files
# ├── server-north-31000.conf
# ├── web-export-pdf-template.conf
# ├── web-galaxy.conf
# ├── web-galaxy-dark.conf
# ├── web-operation-center.conf
# ├── webserver.crt
# └── webserver.key
# 0 directories, 7 files
tree /root/uap-global-volume/nginx-conf-files

# 查看指定volume的文件（nginx配置文件）
# listen 80;
# listen       443 ssl;
grep listen /root/uap-global-volume/nginx-conf-files/web-galaxy.conf

# 反挂载
umount /root/uap-global-volume
```

【示例2】k3s集群中pod使用glusterfs的方法，以uap空间的uap微服务使用的uap-global pvc为例说明如下：

注意，高版本的k3s或k8s删除了glusterfs的in-tree支持，需安装额外的csi驱动才能正常使用glusterfs。其实k3s的版本经过两次降级，最早用的是k3s当时的最新版本，一次降级是因为uap-tidb-operator依赖了某些低版本的k8s api，二次降级是为了使用in-tree glusterfs，并且更准确的说，二次降级不仅仅是降级，因为k3s删除了k8s官方的大部分in-tree存储层支持（这不是k8s的核心功能，k3s仍然是通过cncf认证的k8s发行版），所以使用了某个支持in-tree glusterfs的k3s补丁版（参考 https://github.com/cjrpriest/k3s-glusterfs）。

注意，为了说明原理，这是完整的示例，所以看起来略显复杂，实际上k3s集群并不会自动创建uap空间，也不维护uap空间。

```sh
# 在所有的k3s主节点（前三台）执行，创建uap-global的glusterfs volume目录
sh /opt/k3s/utils/gluster/host/mkdir-for-brick.sh --k8sPvNamespace=uap --k8sPvName=global

# 在任意k3s主节点（例如节点1）执行，创建uap-global的glusterfs volume
# 注意续行符，这是多行命令
sh /opt/k3s/utils/gluster/create-and-start-gluster-volume.sh --k8sPvNamespace=uap --k8sPvName=global \
  --glusterNode=k3s-node-1 --glusterNode=k3s-node-2 --glusterNode=k3s-node-3

# 设置kubeconfig环境变量，否则kubectl和helm命令可能无法正常执行
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# 创建uap空间
kubectl create namespace uap

# 授权给uap空间
# 注意续行符，这是多行命令
kubectl create clusterrolebinding uap-default-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=uap:default

# 安装glusterfs-positioner到uap空间
sh /opt/k3s/utils/gluster/install-glusterfs-positioner-for-k8s-namespace.sh --k8sNamespace=uap --endpoint=<虚ip>

# 创建uap-global pvc对应的pv
sh /opt/k3s/utils/gluster/create-k8s-pv.sh --namespace=uap --name=global --size=100Gi --accessMode=ReadWriteMany

# 创建uap-global pvc
echo '{"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"name":"global","namespace":"uap"},"spec":{"accessModes":["ReadWriteMany"],"resources":{"requests":{"storage":"100Gi"}},"volumeMode":"Filesystem","volumeName":"global"}}' > /tmp/uap-global-pvc.json
kubectl create -f /tmp/uap-global-pvc.json
```

【示例3】k3s集群中pod使用glusterfs的方法，以iottepa空间的tidb备份恢复为例说明如下：

参考 http://gitlab.iottepa.cn/midware/backup-ctl/-/blob/main/README.md

### etcd的使用方法

k3s主节点读写etcd集群，并把k3s集群的所有数据都保存落盘到etcd集群，因此k3s本身是无状态的，所有的数据都保存到了etcd集群。

```sh
# 查看etcd集群成员列表
ETCDCTL_API=3 etcdctl member list -w table

# 查看成员是否健康
ETCDCTL_API=3 etcdctl endpoint health --endpoints=http://k3s-node-1:2379,http://k3s-node-2:2379,http://k3s-node-3:2379

# 查看k3s主节点的etcd连接字符串
# K3S_DATASTORE_ENDPOINT="http://k3s-node-1:2379,http://k3s-node-2:2379,http://k3s-node-3:2379"
# K3S_TOKEN=""
# K3S_URL=""
cat /etc/systemd/system/k3s.service.env
```

### keepalived的使用方法

keepalived只用于绑定虚ip，注意k3s集群并不依赖keepalived。

```sh
# 查看keepalived运行状态
systemctl status keepalived

# 重启keepalived服务，如果宿主机已绑定虚ip，则触发虚ip漂移
systemctl restart keepalived

# 查看keepalived配置
cat /etc/keepalived/keepalived.conf
```