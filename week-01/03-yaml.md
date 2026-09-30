# 第 3 天：用 YAML 描述期望状态

[上一课](02-workloads.md) · [目录](README.md) · [下一课](04-networking.md)

**用时：60 分钟。** 今天把命令变成可以保存、检查和重复使用的配置文件。

## 1. 准备实验空间

```bash
# 先在终端进入本仓库根目录
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl config current-context
kubectl apply -f week-01/manifests/namespace.yaml
kubectl delete deployment hello -n cka-w1 --ignore-not-found
```

这里删除的是昨天在本课命名空间中创建的 `hello`，它管理的 Pod 也会随之删除。今天改用名为 `web` 的应用。

`apply -f` 表示读取文件，并请求集群达到文件描述的状态。第一次一般显示 `created`，已存在但修改了内容时可能显示 `configured`，没有变化时通常显示 `unchanged`。

Namespace 昨天通过 `create` 建立，首次用 `apply` 管理时可能提示缺少 `last-applied-configuration` 注解并自动补上，这是两种管理方式衔接时的提示。

## 2. YAML 是描述文件，不是按行执行的脚本

打开 [web-deployment.yaml](manifests/web-deployment.yaml)，先看其骨架：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: cka-w1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.30.5-alpine
```

这是解释用的骨架，实际操作使用随教程提供的完整文件。

| 字段 | 它描述什么 |
| --- | --- |
| `apiVersion` | 使用哪一组、哪一版 Kubernetes API |
| `kind` | 资源类型；这里是 Deployment |
| `metadata.name` | Deployment 的名字 |
| `metadata.namespace` | 它属于哪个命名空间 |
| `spec` | 期望状态 |
| `spec.replicas` | 希望有几个 Pod 副本 |
| `spec.selector.matchLabels` | Deployment 如何匹配所管理的 Pod |
| `spec.template` | 创建新 Pod 时使用的模板 |
| `template.metadata.labels` | 贴在 Pod 上的标签 |
| `template.spec.containers` | Pod 中要运行的容器列表 |

为什么有两个 `metadata`？外层描述 Deployment 本身；`template` 内层描述未来创建的 Pod。这两个层级不能随意互换。

`selector.matchLabels.app: web` 必须与 Pod 模板中的 `labels.app: web` 匹配。标签是键值对，`app` 是这里采用的习惯命名，不是 Kubernetes 强制要求的特殊单词。

### YAML 只先记四件事

1. 用空格缩进，本教程每层两个空格，不用 Tab。
2. 冒号后有空格，例如 `replicas: 2`。
3. `-` 表示列表项，所以 `containers` 可以包含多个容器。
4. 层级决定含义；缩进错了，可能是完全不同的配置。

完整文件里另外几个字段：`containerPort: 80` 声明容器端口信息，并不会让程序自动监听；`imagePullPolicy: IfNotPresent` 允许复用节点已有镜像；`resources` 为小型练习设置资源请求和上限。`50m` 是 0.05 个 CPU，`32Mi` 是 32 MiB 内存。资源调度和限制的细节留到第 2 周。

## 3. 应用完整配置并验证

```bash
kubectl apply -f week-01/manifests/web-deployment.yaml
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
kubectl get deployments,pods -n cka-w1
kubectl get pods -n cka-w1 -l app=web --show-labels
```

预期 `web` 的就绪副本数为 `2/2`。如果不满足，先 `describe` 和看事件，不要反复执行 `apply` 来碰运气。

再执行一次完全相同的 `apply`。通常显示 `unchanged`，也不会因此创建第二个名为 `web` 的 Deployment。

## 4. 修改文件，再让集群跟上

保留参考文件，给自己复制一份练习用配置：

```bash
mkdir -p week-01/practice
cp week-01/manifests/web-deployment.yaml week-01/practice/web-deployment.yaml
nano week-01/practice/web-deployment.yaml
```

将 `replicas: 2` 改成 `replicas: 3`。在 nano 中按 `Ctrl+O`、回车保存，再按 `Ctrl+X` 退出。也可以用你熟悉的文本编辑器。

先检查差异，再应用：

```bash
kubectl diff -f week-01/practice/web-deployment.yaml
kubectl apply -f week-01/practice/web-deployment.yaml
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
kubectl get deployment web -n cka-w1
```

`kubectl diff` 有差异时退出码为 1，这是正常行为；它本身不应用修改。集群最终应显示 `3/3`。

再应用原始文件，恢复两个副本：

```bash
kubectl apply -f week-01/manifests/web-deployment.yaml
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
```

原文件一直保存 `replicas: 2`，所以这次把已管理的该字段恢复为 2。文件不会自动监控集群；只有提交修改后，控制器才按新的期望状态协调。

## 5. Namespace 为什么重要？

比较：

```bash
kubectl get deployment web -n cka-w1
kubectl get deployment web -n default
kubectl get pods -A
```

你现有集群的 `default` 中可能也有一个 `web`，它与本课 `cka-w1/web` 是不同对象。若没有，则第二条返回 `NotFound`。

Pod、Deployment、Service 属于命名空间；Node、Namespace 本身则是集群范围资源。命名空间分组不自动限制网络通信或权限。

查不到对象时，先问两件事：**是不是正确的 context？是不是正确的 Namespace？**

## 6. 开始学会自己查字段

```bash
kubectl explain deployment.spec.replicas
kubectl explain deployment.spec.template.spec.containers
kubectl get deployment web -n cka-w1 -o yaml
```

`explain` 是字段说明书；`get -o yaml` 是对象当前的完整表示，里面会出现系统补充的 `status`、时间、UID 等。编写自己的配置时不需要复制这些运行状态。

可选：体验生成 YAML 草稿，不创建资源：

```bash
kubectl create deployment draft -n cka-w1 --image=nginx:1.30.5-alpine --replicas=2 --dry-run=client -o yaml
```

`--dry-run=client` 表示客户端生成而不提交创建；`-o yaml` 指定输出形式。它适合起草，但仍需要理解和检查字段。

## 7. 验收

- [ ] 能解释两个 `metadata` 的区别。
- [ ] 能从文件把副本数改成 3，再恢复成 2。
- [ ] 知道 `containerPort` 不会自动暴露公网端口。
- [ ] 查询资源时能明确写出命名空间。
- [ ] 能用 `kubectl explain` 查询一个不熟悉的字段。

思考：如果用 `kubectl scale` 临时改成 4，之后又应用原文件中的 `replicas: 2`，最终会怎样？见 [参考答案](answers.md)。

资料：[声明式配置管理](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/) · [Namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
