# 第一周命令速查

[目录](README.md) · [常见问题](troubleshooting.md)

所有示例针对 `minikube` 的 `cka-w1`。先确认目标，再操作。

## 每次开始

```bash
# 先在终端进入本仓库根目录
minikube status -p minikube
kubectl config use-context minikube
kubectl config current-context
kubectl get nodes
```

## 日常观察

```bash
kubectl get namespaces
kubectl get pods -n cka-w1
kubectl get pods -n cka-w1 -o wide
kubectl get pods -n cka-w1 --show-labels
kubectl get pods -n cka-w1 -l app=web
kubectl get deployments,replicasets,pods,services -n cka-w1
kubectl describe pods -n cka-w1 -l app=web
kubectl get events -n cka-w1 --sort-by=.metadata.creationTimestamp
kubectl logs -n cka-w1 -l app=web --tail=20 --prefix=true
kubectl exec -n cka-w1 deployment/web -- nginx -v
```

`get all` 并不包含所有资源类型；本周使用显式的资源列表，避免误以为看到了全部内容。

## 应用配置与等待

```bash
kubectl apply -f week-01/manifests/namespace.yaml
kubectl apply -f week-01/manifests/web-deployment.yaml
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
kubectl apply -f week-01/manifests/web-service.yaml
kubectl apply -f week-01/manifests/toolbox-pod.yaml
kubectl wait -n cka-w1 --for=condition=Ready pod/toolbox --timeout=180s
```

命名空间先创建，再创建其中的资源；不要把整个教程目录递归提交给 kubectl。

## 扩容与查配置

```bash
kubectl scale deployment web -n cka-w1 --replicas=3
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
kubectl get deployment web -n cka-w1 -o yaml
kubectl explain deployment.spec.replicas
```

需要恢复两个副本时，应用原始的 `web-deployment.yaml`。

## 验证网络

```bash
kubectl get service web -n cka-w1
kubectl describe service web -n cka-w1
kubectl get endpointslices -n cka-w1 -l kubernetes.io/service-name=web
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

本地访问在两个终端操作：

```bash
kubectl port-forward -n cka-w1 service/web 8080:80
```

```bash
curl -I http://127.0.0.1:8080
```

## 常见短参数

| 参数 | 含义 |
| --- | --- |
| `-n cka-w1` | 选择命名空间 |
| `-A` | 所有命名空间，适合观察 |
| `-l app=web` | 按标签筛选 |
| `-o wide` | 增加节点、IP 等输出 |
| `-o yaml` | 以 YAML 输出 |
| `-w` | 持续观察，Ctrl+C 退出 |
| `-f 文件路径` | 在 apply 等命令中指定文件 |
| `logs -f` | 持续跟随日志，Ctrl+C 退出 |
| `--dry-run=client` | 客户端模拟生成，不提交创建 |
| `--context=minikube` | 为这条命令显式选择连接上下文 |

同一个 `-f` 在不同命令中有不同含义，要结合命令理解。
