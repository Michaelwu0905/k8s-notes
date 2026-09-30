# 第一周常见问题

[目录](README.md) · [命令速查](cheatsheet.md)

遇到问题，先保留**完整命令、完整错误、当前 context、命名空间**。从与你现象相符的一项开始，不要同时修改多处配置。

## 1. kubectl 连接失败

可能看到 `connection refused`、超时，或无法连接 API Server。

先检查：

```bash
docker version
minikube status -p minikube
kubectl config get-contexts
kubectl config current-context
```

判断顺序：

1. Docker 没有 Server 信息：先启动 Docker Desktop。
2. Docker 正常，已有 Minikube 已停止：执行 `minikube start -p minikube`。
3. 集群正常，但 context 不对：执行 `kubectl config use-context minikube`。
4. 仍失败：保留 `minikube status` 和错误输出进一步分析，不直接删除集群。

若错误是 `permission denied` 或 `operation not permitted`，还可能来自运行命令的工具沙箱或权限边界，不能据此判断集群已经停止。在 Mac 自己的终端执行同样的只读检查进行对比。不要给 Docker socket 设置所有人可写的权限，也不要用 `sudo kubectl` 掩盖问题。

## 2. command not found

```bash
command -v brew
command -v minikube
command -v kubectl
```

只安装缺少的工具。安装后依照 Homebrew 提示配置 PATH，并重新打开终端。如果 Docker Desktop 已安装但找不到 `docker`，检查它的 CLI 工具安装设置。

若 `uname -m` 是 `x86_64` 而硬件是 Apple Silicon，检查是否通过 Rosetta 运行终端。优先使用原生 ARM64 环境和支持 ARM64 的镜像。

## 3. Namespace 或资源 NotFound

```bash
kubectl config current-context
kubectl get namespaces
kubectl get pods -A
```

先检查是不是命名空间写错了。创建本课 Namespace：

```bash
kubectl apply -f week-01/manifests/namespace.yaml
```

`-n cka-w1` 与 `-n default` 查询的是不同范围。你原来的 default 中也可能有 `web`，不要误以为它就是教程创建的资源。

## 4. AlreadyExists

这是「对象已经存在」，不是「必须删除重装」。

先用 `get` / `describe` 核对它是不是自己的练习资源。YAML 实验使用 `apply` 更新；使用 `create` 的第 2 天练习，重做时可继续使用已有 Deployment，或仅删除那个明确的练习对象后再建。

## 5. ImagePullBackOff / ErrImagePull

先看 Pod 的 Events：

```bash
kubectl describe pods -n cka-w1 -l app=web
kubectl get events -n cka-w1 --sort-by=.metadata.creationTimestamp
```

| 事件中的线索 | 下一步 |
| --- | --- |
| `manifest unknown`、`not found` | 核对镜像仓库名和标签 |
| `unauthorized`、`denied` | 核对仓库是否需要认证 |
| `timeout`、DNS 或 TLS 错误 | 检查镜像仓库访问、网络和代理配置 |
| `toomanyrequests`、限流 | 按仓库提示认证或稍后重试 |
| `no matching manifest` | 核对镜像是否提供节点所需的 ARM64 架构 |

第 6 天的错误镜像是故意写错标签，其他时候不能一概认为都是同一原因。

### Mac 能拉取镜像，但节点拉取失败

Mac 上的 Docker 镜像存储与 Minikube 节点内的镜像存储不是同一个概念。可以使用官方支持的镜像加载方式，把可用镜像放进指定 profile：

```bash
docker pull nginx:1.30.5-alpine
docker pull busybox:1.37.0
minikube image load nginx:1.30.5-alpine -p minikube
minikube image load busybox:1.37.0 -p minikube
```

本课 YAML 的 `imagePullPolicy: IfNotPresent` 允许复用节点中的镜像。加载完成后等待 kubelet 重试；必要时只删除本课失败的应用 Pod，让 Deployment 补建。若 Mac 自己也拉取失败，先处理访问仓库的问题，镜像加载无法绕过它。

不要因为网络慢就随意替换成来源不明的镜像仓库。本课只有两个应用镜像，成功下载后可复用。

## 6. Pending / ContainerCreating 很久

短暂出现通常是正常过程；持续很久需要看事件：

```bash
kubectl describe pods -n cka-w1 -l app=web
kubectl describe node minikube
```

如果事件出现 `Insufficient cpu` 或 `Insufficient memory`，说明调度所需资源不足。先检查是否有多余的本课练习副本；本周基线是 2 个 web 和 1 个 toolbox。现有集群还有其他应用，不能直接删除它们来腾资源。

`ContainerCreating` 也可能卡在镜像、网络沙箱或卷准备环节，具体看 Events。

默认 Minikube 未必启用 metrics-server，因此 `kubectl top` 报 Metrics API 不可用并不等于整个集群故障。本周不依赖它。

## 7. CrashLoopBackOff

这通常表示容器启动后反复退出并进入重试退避。与镜像根本未能拉取不同，应同时检查应用日志和退出原因。

```bash
kubectl get pods -n cka-w1
kubectl describe pods -n cka-w1 -l app=web
kubectl logs deployment/web -n cka-w1 --tail=50
```

如需看某个容器上一次运行的日志，先用实际 Pod 名称设置变量，再执行：

```bash
FAILED_POD=请替换成实际失败的Pod名称
kubectl logs "$FAILED_POD" -n cka-w1 --previous
```

第一行的值必须替换，不能原样执行。若容器从未重启，`--previous` 没有对应日志也是正常的。本周故障练习不要求主动制造 CrashLoopBackOff，先学会辨认。

## 8. YAML 报错

- 检查缩进是否混入 Tab，冒号后是否有空格。
- 检查 `apiVersion` 和 `kind` 是否正确。
- 检查 selector 与 Pod 模板的 labels 是否匹配。
- 检查文件路径是否相对于本仓库根目录。

可以先让服务端验证，而不真正保存本次资源修改：

```bash
kubectl apply --dry-run=server -f week-01/manifests/web-deployment.yaml
```

这仍然需要连接集群，并且 Namespace 应已存在。不要把「dry-run」理解为所有命令都能离线执行。

Deployment 的 selector 等字段有不可变约束。第 3 天只修改副本数，不随意改 selector。如果只是想恢复练习，优先重新应用参考文件。

## 9. 本地 8080 访问失败

依次确认：

1. 执行 `port-forward` 的终端是否仍在运行？
2. 它是否输出了 `Forwarding from ...`？
3. curl 使用的端口是否与转发左边一致？
4. 对应 Pod 是否就绪？Service selector 是否正确？

如果提示端口被占用：

```bash
kubectl port-forward -n cka-w1 service/web 8081:80
```

再访问 `http://127.0.0.1:8081`。端口转发选择的 Pod 被删除或替换后，转发可能中断，需要重新运行。

## 10. Pod Running，但 Service 不通

```bash
kubectl get pods -n cka-w1 -l app=web --show-labels
kubectl describe service web -n cka-w1
kubectl get endpointslices -n cka-w1 -l kubernetes.io/service-name=web -o yaml
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

先确认标签匹配、后端地址、目标端口，再查应用实际监听情况。`port-forward` 成功不能证明普通 Service 路径成功，所以保留集群内测试。

## 11. 如何恢复本周正常基线

先确认 context 是 `minikube`，并结束之前的端口转发，再按顺序应用：

```bash
kubectl apply -f week-01/manifests/namespace.yaml
kubectl apply -f week-01/manifests/web-deployment.yaml
kubectl apply -f week-01/manifests/web-service.yaml
kubectl apply -f week-01/manifests/toolbox-pod.yaml
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
kubectl wait -n cka-w1 --for=condition=Ready pod/toolbox --timeout=180s
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

这些命令恢复参考文件所管理的字段，并不会自动删除额外创建的资源。如果遗留了故障实验的 Deployment，可在确认归属后单独清理：

```bash
kubectl delete deployment broken-image -n cka-w1 --ignore-not-found
```

若你修改了 Pod 的不可变字段，重新 apply 可能无法恢复。只对本课的 toolbox，可删除后重新应用其 YAML；其他情况先看具体错误。
