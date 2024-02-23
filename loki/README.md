## 定制化loki中间件

```sh
# 安装命令, 在主节点执行
helm install loki-stack http://helm.iottepa.cn:32021/charts/uap-loki-stack-2.5.1.tgz

# 修改loki日志保存期限（7天）
helm upgrade loki-stack http://helm.iottepa.cn:32021/charts/uap-loki-stack-2.5.1.tgz --reuse-values \
    --set loki.config.chunk_store_config.max_look_back_period=168h \
    --set loki.config.limits_config.reject_old_samples_max_age=168h \
    --set loki.config.limits_config.retention_period=168h \
    --set loki.config.table_manager.retention_period=168h
```