## 定制化nginx中间件

nginx动态加载：

在微服务架构中，为了实现Nginx配置的动态加载，我们使用了一个创新的方法，充分利用了Kubernetes的持久卷（Persistent Volumes）和全局PVC文件湖。这个方法允许Nginx和微服务在同一个Kubernetes集群中共享文件，并实现动态加载Nginx配置文件，以满足快速部署和配置微服务的需求。

概念背景：
在微服务架构中，需要快速部署和调整微服务以适应变化的需求。Nginx是一个常用的反向代理和负载均衡服务器，通常用于微服务架构中。为了实现快速响应配置的变更，我们引入了 "nginx动态加载" 的概念。

全局PVC文件湖的作用：
全局PVC文件湖是该概念的核心，它充当了存储Nginx配置文件和静态资源的中央存储库。该目录包含两个子目录：nginx-static-files 和 nginx-conf-files，分别用于存储静态文件和Nginx配置文件。

微服务动态生成配置文件：
微服务可以动态生成Nginx配置文件，并将其放置在 nginx-conf-files 目录中。这使得微服务能够自主管理其Nginx配置，而Nginx可以立即检测到配置文件的变更。

Nginx的动态加载机制：
Nginx配置为监控全局PVC文件湖中的配置文件，并在配置发生变更时，支持动态加载新的配置。这可以通过重新启动Nginx进程、重启Nginx Pod，或执行 nginx -s reload 命令来实现。

优点和应用场景：
这一方法的优势在于实现了快速响应配置变更的能力，同时提供了一种规范的文件访问和共享方式，使微服务可以轻松地管理Nginx配置。它适用于需要灵活部署和动态配置的微服务架构场景。

部署和管理注意事项：
在部署这一方法时，需要特别注意确保正确的权限和访问控制，以确保Nginx能够访问全局PVC文件湖中的文件。

通过 "nginx动态加载"，我们实现了微服务和Nginx之间的高度整合，使它们能够协同工作以适应快速变化的需求，提高了整个系统的灵活性和可维护性。

这是一个创新且有前景的方法，可以满足微服务架构的动态配置需求。

```sh
# 安装命令, 在主节点执行
helm install nginx http://helm.iottepa.cn:32021/charts/uap-nginx-{版本}.tgz -n {命名空间}

# 热加载nginx配置文件
kubectl get pod -l app=nginx -oname -n {命名空间} | xargs -I{} kubectl exec -it {} -n {命名空间} -- sh -c "nginx -s reload"

# 支持动态新增或删除端口，要明确列出所有的接口，注意索引从0开始，连续递增
helm upgrade nginx http://helm.iottepa.cn:32021/charts/uap-nginx-{版本}.tgz -n {命名空间} --reuse-values \
    --set service.ports[0].name={端口1名称} --set service.ports[0].port={端口1} \
    --set service.ports[1].name={端口2名称} --set service.ports[1].port={端口2} \
    --set service.ports[2].name={端口3名称} --set service.ports[2].port={端口3}
```