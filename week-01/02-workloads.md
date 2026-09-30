# 第 2 天：部署应用，观察自动补建与扩容

[上一课](01-cluster.md) · [目录](README.md) · [下一课](03-yaml.md)

**用时：60 分钟。** 今天掌握 Pod 和 Deployment 的关系，并练习四个观察工具：`get`、`describe`、`logs`、`exec`。

## 1. 开始前检查

```bash
# 先在终端进入本仓库根目录
kubectl config use-context minikube
kubectl config current-context
kubectl get nodes
kubectl get namespace cka-w1
```

最后一条第一次返回 `NotFound` 是预期的。若已经存在，请先检查里面是否是自己的本课练习资源；如果不是，先辨认用途，不要覆盖。

创建专门的实验空间：

```bash
kubectl create namespace cka-w1
```

重复练习时提示 `AlreadyExists` 表示已经创建，无需删除。接下来每条资源操作都带 `-n cka-w1`。

## 2. 先启动一个独立 Pod

```bash
kubectl run solo -n cka-w1 --image=nginx:1.30.5-alpine --restart=Never
kubectl get pods -n cka-w1 -w
```

`solo` 是 Pod 名字，`--image` 指定镜像，`--restart=Never` 设置容器退出后不在这个 Pod 内自动重启。**这条命令创建的是 Pod，不是 Deployment。**

拉取镜像、创建容器可能需要一段时间。常见输出变化：

```text
NAME   READY   STATUS              RESTARTS   AGE
solo   0/1     ContainerCreating   0          ...
solo   1/1     Running             0          ...
```

看到 `1/1 Running` 后按 `Ctrl+C`，只停止观察，不会停止 Pod。若出现 `ImagePullBackOff`，先到 [问题排查](troubleshooting.md) 查看原因。

解释这几列：

- `READY 1/1`：一个容器被标记为就绪，共一个容器。
- `STATUS Running`：显示的 Pod 状态；不等于应用的所有业务功能都正常。
- `RESTARTS`：容器重启次数，不是 Pod 被重新创建的次数。

本周暂未配置 readinessProbe，所以还不能把 Ready 当作 HTTP 健康检查结果；我们会另外发请求验证，探针留到第 2 周。

看看详情，再删除它：

```bash
kubectl describe pod solo -n cka-w1
kubectl delete pod solo -n cka-w1
kubectl get pods -n cka-w1
```

这个独立 Pod 被删除后，没有 Deployment/ReplicaSet 要求补建它，因此不会自动出现一个新 `solo`。

## 3. 换成 Deployment 管理应用

```bash
kubectl create deployment hello -n cka-w1 --image=nginx:1.30.5-alpine --replicas=1
kubectl rollout status deployment/hello -n cka-w1 --timeout=180s
kubectl get deployments,replicasets,pods -n cka-w1
```

`rollout status` 等待当前 Deployment 部署完成。成功时会看到类似：

```text
deployment "hello" successfully rolled out
```

资源关系是：

```text
Deployment hello
 └─ ReplicaSet：维持所需的 Pod 数量
     └─ Pod hello-一串字符
         └─ Nginx 容器
```

不要求背 Pod 名称后缀，也不需要手工创建 ReplicaSet。本周先由 Deployment 管理它。

## 4. 四种观察方式

逐条运行，每条都回答它能告诉你什么：

```bash
kubectl get pods -n cka-w1 -o wide
kubectl describe deployment hello -n cka-w1
kubectl describe pods -n cka-w1 -l app=hello
kubectl logs deployment/hello -n cka-w1 --tail=20
kubectl exec deployment/hello -n cka-w1 -- nginx -v
```

| 命令 | 回答的问题 |
| --- | --- |
| `get` | 有哪些对象？数量和状态怎样？ |
| `describe` | 配置、状态和关联事件有什么线索？ |
| `logs` | 容器中的程序向标准输出/错误输出写了什么？ |
| `exec` | 能否在运行中的容器里执行一个检查命令？ |

`-l app=hello` 是按标签筛选；`kubectl create deployment hello` 为 Pod 模板设置了这个标签。执行 `kubectl get pods -n cka-w1 --show-labels` 可以确认。

`exec` 中的 `--` 分隔 kubectl 的参数和容器里要运行的命令。`nginx -v` 在 Pod 内执行，Mac 不需要安装 Nginx。通过 Deployment 执行 `logs` 或 `exec` 时，会选中其中一个 Pod，不表示遍历全部副本。

## 5. 亲眼观察自动补建

先确认当前副本数为 1。打开两个终端，都先进入本仓库根目录，并确认 context 为 `minikube`。

终端 A 持续观察：

```bash
kubectl get pods -n cka-w1 -l app=hello -w
```

终端 B 删除匹配标签的 Pod：

```bash
kubectl delete pods -n cka-w1 -l app=hello
```

这里按标签删除，当前只有一个匹配的 Pod。如果你先扩容了，这条命令会删除所有匹配的副本。

在 A 中观察：旧 Pod 终止，新名称的 Pod 出现，最终恢复为一个运行的副本。观察完成按 `Ctrl+C`。

**删除 Pod 并没有修改 Deployment 的期望副本数。** ReplicaSet 仍在要求一个副本，因此创建替代 Pod。这是 Pod 的重新创建，不是旧 Pod 内容器的重启。

## 6. 手动扩容到三个副本

```bash
kubectl scale deployment hello -n cka-w1 --replicas=3
kubectl rollout status deployment/hello -n cka-w1 --timeout=180s
kubectl get deployment hello -n cka-w1
kubectl get pods -n cka-w1 -l app=hello -o wide
```

预期 Deployment 的 `READY` 为 `3/3`，有三个应用 Pod。单节点 Minikube 中，这三个 Pod 都可能位于同一个节点。

三个副本不等于三台机器；本例不能提供节点级高可用。

最后恢复到一个副本，节省资源：

```bash
kubectl scale deployment hello -n cka-w1 --replicas=1
kubectl rollout status deployment/hello -n cka-w1 --timeout=180s
```

## 7. 自测与验收

合上本页，完成「查看 Pod → 查看事件 → 扩成 2 个副本 → 恢复成 1 个副本」。允许查 `kubectl --help`。

- [ ] 能解释为什么删除 `solo` 与删除 `hello` 的 Pod 结果不同。
- [ ] 能说明 `get`、`describe`、`logs`、`exec` 的用途。
- [ ] 知道 `3/3` 表示三个就绪副本，不是三台节点。
- [ ] 最终 `hello` 恢复为一个副本。

思考：若真正希望应用不再运行，应删除 Pod 还是修改/删除 Deployment？见 [参考答案](answers.md)。

资料：[Pod](https://kubernetes.io/docs/concepts/workloads/pods/) · [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
