# 第 4 天：让应用可以访问

[上一课](03-yaml.md) · [目录](README.md) · [下一课](05-review.md)

**用时：60 分钟。** 今天区分「应用运行了」和「应用能访问」，分别从 Mac 和集群内部验证。

## 1. 恢复到已知起点

```bash
# 先在终端进入本仓库根目录
kubectl config use-context minikube
kubectl config current-context
kubectl apply -f week-01/manifests/namespace.yaml
kubectl apply -f week-01/manifests/web-deployment.yaml
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
kubectl get pods -n cka-w1 -l app=web -o wide
```

看到两个就绪 Pod 后继续。每个 Pod 有 IP，但 Pod 被替换时 IP 可能变化。调用方不适合一直手工追踪这些地址，因此需要 Service。

## 2. Service：给一组 Pod 提供稳定入口

打开 [web-service.yaml](manifests/web-service.yaml)：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: cka-w1
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
```

逐项理解：

- `type: ClusterIP`：创建一个主要供集群内部使用的 Service。
- `selector: app: web`：匹配同一命名空间里带该标签的 Pod。
- `port: 80`：客户端访问 Service 的端口。
- `targetPort: 80`：请求最终发往后端 Pod 的端口，应有应用监听。

Service 通过标签找 Pod，不是通过 Deployment 的名称找 Pod。这里资源恰好都叫 `web`，只是为了方便记忆。

```text
集群内客户端
   ↓ 访问 web:80
Service web（ClusterIP）
   ↓ 匹配 app=web 的后端
Pod A:80 或 Pod B:80 → Nginx
```

创建并检查：

```bash
kubectl apply -f week-01/manifests/web-service.yaml
kubectl get service web -n cka-w1
kubectl describe service web -n cka-w1
kubectl get endpointslices -n cka-w1 -l kubernetes.io/service-name=web
```

EndpointSlice 记录 Service 对应的后端地址等信息。预期能看到应用 Pod 的地址；可以与 `get pods -o wide` 对照。它不需要你手工维护。

## 3. 从 Mac 访问：先用端口转发

终端 A：

```bash
kubectl port-forward -n cka-w1 service/web 8080:80
```

看到类似 `Forwarding from 127.0.0.1:8080 -> 80` 后，让这个终端保持运行。

终端 B：

```bash
curl -I http://127.0.0.1:8080
curl http://127.0.0.1:8080
```

预期状态码 `200`，正文包含 Nginx 欢迎页面。也可以在浏览器中打开 [本机应用](http://127.0.0.1:8080)。

`8080:80` 左边是 Mac 的本地端口，右边是 Service 端口。默认只在本地回环地址监听；不需要使用管理员权限。

**这里有一个容易混淆的地方：** `port-forward service/web` 会选择一个匹配的 Pod 建立转发，它不经过普通的 Service ClusterIP 转发路径，也不能用来证明多副本负载均衡正常。所以接下来还要做集群内部测试。

先在 A 按 `Ctrl+C`，再试一次 curl，你会发现本地连接失败。这只说明转发通道关闭了，集群里的应用并没有停止。

如果 8080 被占用，改成 `8081:80`，并把本地访问 URL 相应改成 8081；不要随意终止占用端口的其他程序。

## 4. 从集群内部验证 Service

创建一个小工具 Pod，它用 BusyBox 提供 `wget` 等命令：

```bash
kubectl apply -f week-01/manifests/toolbox-pod.yaml
kubectl wait -n cka-w1 --for=condition=Ready pod/toolbox --timeout=180s
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

预期输出 Nginx 欢迎页。`wget -qO-` 表示安静下载并把正文输出到终端，`-T 5` 设置超时。

这里的程序运行在 `toolbox` 内，`web` 由集群 DNS 解析为同命名空间 Service 的地址。再试完整域名：

```bash
kubectl exec -n cka-w1 toolbox -- nslookup web.cka-w1.svc.cluster.local
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web.cka-w1.svc.cluster.local:80
```

在本课默认集群域 `cluster.local` 下，完整域名由「Service 名 + Namespace + svc + 集群域」组成。换了命名空间的客户端就不应假设短名 `web` 仍指向这里。

macOS 使用 Docker 驱动时，宿主机通常不能直接访问集群内部 IP。本课统一使用端口转发，不要求你修改 Mac 路由，也不使用 `minikube ip` 拼接 NodePort 地址。

## 5. 看一眼访问日志

```bash
kubectl logs -n cka-w1 -l app=web --tail=10 --prefix=true
```

这次使用标签选择多个 Pod，并给输出加上来源前缀。前面的 HTTP 请求应该留下访问记录。没有每个副本都有记录并不表示失败，流量可能只到过其中一部分副本。

## 6. 验收

- [ ] 通过 Mac 的 8080 端口访问成功。
- [ ] 停止转发后，知道为什么本机端口不再可用。
- [ ] 从 `toolbox` 访问 `http://web:80` 成功。
- [ ] 能解释 `port`、`targetPort`、`containerPort` 的区别。
- [ ] 能找到 Service 的 selector 以及对应 Pod 的 labels。

思考：Pod 全部 Running，但 Service 的 selector 写成 `app: wrong`，访问还能成功吗？有哪些命令能证明原因？第 6 天亲手试一次。

保留 `web`、Service 和 `toolbox`，周末继续。工具 Pod 中的 `sleep 86400` 使容器长时间运行；约一天后进程结束，默认重启策略会重新启动它。

资料：[Service](https://kubernetes.io/docs/concepts/services-networking/service/) · [端口转发](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/) · [Service DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
