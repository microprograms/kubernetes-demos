## 定制化openebs-jiva-provisioner

```sh
# 安装命令, 在主节点执行
helm install jiva uap-openebs-jiva-provisioner-{版本}.tgz -n openebs --create-namespace

# 设置为默认的storageclass
kubectl patch storageclass openebs-jiva-csi-default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 取消设置为默认
kubectl patch storageclass openebs-jiva-csi-default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```