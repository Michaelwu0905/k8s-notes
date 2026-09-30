# 第一周参考答案

[目录](README.md) · [第 7 天任务](07-assessment.md)

先亲手做，再对照。以下命令均在本仓库根目录下操作，先执行 `export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"`，并核对三个节点。

## 第 1 天

UTM 在 Mac 上运行三台 Ubuntu VM；K3s 在 VM 上运行 Kubernetes；kubectl 从 Mac 读取独立 kubeconfig 并访问 master 的 API Server。

关闭一台 worker 后，它的 Pod 可能受影响，节点会变为 NotReady；关闭唯一的 master 后 API Server 不可用，即使两个 worker 仍开机也不能正常管理集群。Mac 睡眠会暂停所有 VM。恢复后先检查 UTM、`KUBECONFIG` 和 `kubectl get nodes`，不要一看到连接失败就重建集群。

## 第 2 天

独立 Pod 被删除后没有控制器负责替代它。Deployment 管理的 Pod 被删除后，ReplicaSet 仍需要满足副本数，会创建新 Pod。

希望应用停下来，可以把 Deployment 副本数改为 0，或在确定不再需要时删除 Deployment。仅删除受管理的 Pod 会触发补建。这里的动作都应限定到目标 Namespace。

## 第 3 天

当原配置中的 `spec.replicas` 一直由 `apply` 管理，临时 `scale` 到 4 后再应用写着 2 的文件，会回到 2 个副本。长期配置应记录在自己的 YAML 中，避免文件与当前状态互相矛盾。

## 第 4 天

- `containerPort`：容器端口的声明，不会替程序监听，也不自动开放 Mac 端口。
- `Service.port`：客户端访问 Service 的端口。
- `Service.targetPort`：请求被送到后端 Pod 的端口。
- `port-forward 8080:80`：本机 8080 转发到所指定对象的 80 端口；当对象是 Service 时，右侧填写 Service 端口。

selector 错误时，Service 找不到正确的后端。用 `get pods --show-labels`、`describe service` 和 `get endpointslices` 比较配置与实际后端。

## 第 6 天：重建练习的一种解法

```bash
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl apply -f week-01/manifests/web-deployment.yaml
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
kubectl apply -f week-01/manifests/web-service.yaml
kubectl get endpointslices -n cka-w1 -l kubernetes.io/service-name=web
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

终端 A：

```bash
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl port-forward -n cka-w1 service/web 8080:80
```

终端 B：

```bash
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
curl -I http://127.0.0.1:8080
kubectl logs -n cka-w1 -l app=web --tail=10 --prefix=true
```

结束后在 A 按 `Ctrl+C`。若 toolbox 不存在，先应用其 YAML 并等待 Ready。

## 第 7 天：配置与验证

完整参考配置见 [assessment.yaml](solutions/assessment.yaml)。若只是查答案，阅读文件即可；要执行时先确认 `cka-w1-check` 是自己的本课验收空间。

先确保命名空间存在，再应用答案。第一条管道生成 Namespace 配置交给 `apply`，重复执行不会因名称已存在而失败：

```bash
# 先在终端进入本仓库根目录
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl config current-context
kubectl create namespace cka-w1-check --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f week-01/solutions/assessment.yaml
kubectl rollout status deployment/review-web -n cka-w1-check --timeout=180s
kubectl wait -n cka-w1-check --for=condition=Ready pod/review-client --timeout=180s
kubectl get deployments,pods,services -n cka-w1-check
kubectl get endpointslices -n cka-w1-check -l kubernetes.io/service-name=review-web
kubectl exec -n cka-w1-check review-client -- wget -qO- -T 5 http://review-web:8080
```

预期 Deployment `2/2`，客户端 `1/1 Running`，Service 显示 `8080/TCP`，内部访问输出 Nginx 页面。

### 扩缩容

```bash
kubectl scale deployment review-web -n cka-w1-check --replicas=3
kubectl rollout status deployment/review-web -n cka-w1-check --timeout=180s
kubectl get deployment review-web -n cka-w1-check
kubectl scale deployment review-web -n cka-w1-check --replicas=2
kubectl rollout status deployment/review-web -n cka-w1-check --timeout=180s
```

若自己的 YAML 曾改为 3，也要改回 2。参考答案本来就是 2。

### 删除一个 Pod 并观察补建

先列出 Pod，记下一个实际名字：

```bash
kubectl get pods -n cka-w1-check -l app=review-web
```

终端 A：

```bash
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl get pods -n cka-w1-check -l app=review-web -w
```

终端 B 可以用下面的命令自动选择一个 Pod 名称，再删除。先检查 `printf` 输出确实是 `review-web-...`：

```bash
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
REVIEW_POD=$(kubectl get pods -n cka-w1-check -l app=review-web -o jsonpath='{.items[0].metadata.name}')
printf '%s\n' "$REVIEW_POD"
kubectl delete pod "$REVIEW_POD" -n cka-w1-check
```

`$(...)` 把命令结果保存到变量，JSONPath 取列表第一项的名称。先用看得懂的手工方法也可以，不要求第一周熟练掌握 JSONPath。

在 A 中看到替代 Pod Ready、最终两个副本后按 `Ctrl+C`。再发一次内部 HTTP 请求验证。

### Mac 访问

终端 A：

```bash
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl port-forward -n cka-w1-check service/review-web 8082:8080
```

终端 B：

```bash
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
curl -I http://127.0.0.1:8082
kubectl logs -n cka-w1-check -l app=review-web --tail=10 --prefix=true
```

注意右边是 **8080**，因为它是 Service 的端口，Service 再映射到 Pod 的 80。结束后在 A 按 `Ctrl+C`。

## 十个口头问题参考

1. Mac 运行 UTM 和 kubectl；UTM 提供 Linux VM；K3s 运行集群；kubectl 调用 master 的 API。
2. 可以。多个容器可以在一个 Pod 中协作，本周每个 Pod 只有一个容器。
3. ReplicaSet 按 Deployment 的期望副本数创建替代 Pod。
4. 不一定。三节点集群里调度器仍可能把多个副本放到同一节点，观察 `get pods -o wide` 的 `NODE` 列。
5. 本课 Service 用 selector 匹配同命名空间 Pod 的 labels。
6. 分别是 Service 对外提供的端口、后端目标端口、容器端口声明。
7. ClusterIP 是集群内部虚拟地址；Mac 通常没有访问它的路由。本课从 Mac 使用端口转发，从 toolbox 使用集群内 Service。
8. 不能。还可能有端口、配置、应用逻辑等问题；要做实际请求和健康检查。
9. 容器可能尚未启动，没有应用日志；事件能显示拉取失败的实际原因。
10. 不是。Namespace 参与标识命名空间内的对象，`default/web` 与 `cka-w1/web` 可以同时存在。
