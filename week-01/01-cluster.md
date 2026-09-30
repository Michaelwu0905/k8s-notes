# 第 1 天：理解 Kubernetes，检查现有 Minikube

[返回本周目录](README.md) · 下一课：[部署与观察](02-workloads.md)

**用时：概念 25 分钟，环境检查 20 分钟，探索与验收 15 分钟。** 今天的目标是确认 Ready 节点，并能解释 kubectl、Minikube、Docker 分别做什么。

## 1. 从你已经会的 Docker 出发

你可能运行过 `docker run nginx`。这能启动一个容器。当应用需要多个副本、分布在多台机器上、持续更新时，还需要协调这些操作。

Kubernetes 接收你的要求，例如「保持两个 Nginx 副本运行」，再持续观察实际情况并尝试让它符合要求。这里最重要的词是 **期望状态**。

假设你要求 2 个副本，实际只剩 1 个，控制器就会尝试补建。它不是只执行一次启动指令，而是持续协调。镜像不存在、资源不足等问题仍然需要你处理；Kubernetes 不会自动修复所有应用错误。

## 2. 先认识五个名词

| 名词 | 先这样理解 | 本周例子 |
| --- | --- | --- |
| Cluster，集群 | 一组共同运行 Kubernetes 的节点 | 现有的 Minikube 集群 |
| Node，节点 | 提供 CPU、内存、网络的运行环境 | 本机 Docker 中运行的 Minikube 节点 |
| Pod | Kubernetes 调度的基本单位，包含一个或多个容器 | 一个 Pod 里运行一个 Nginx |
| Deployment | 声明并管理应用副本、更新等期望状态 | 要求 Nginx 保持两个副本 |
| Namespace，命名空间 | 为集群中的一部分资源划分名称范围 | `cka-w1` |

一个 Pod 不等于一个容器：它可以包含多个紧密协作的容器，共享网络等资源。本周先使用「一个 Pod 一个容器」的简单形式。

Namespace 也不是一台虚拟机，更不会自动提供网络隔离。第 3 天会实际比较两个命名空间。

## 3. 你的 Mac 上，集群在哪里？

```text
Mac：终端运行 kubectl 和 minikube
 └─ Docker Desktop 的 Linux 虚拟机
     └─ Minikube 节点容器：minikube
         ├─ Kubernetes 控制平面组件
         ├─ kubelet + 容器运行时
         └─ 你的 Pod → Nginx 容器
```

- **Docker Desktop**：提供运行 Linux 容器的环境。
- **Minikube**：创建和管理本地 Kubernetes 学习集群；你现有 profile 使用 Docker 驱动。
- **kubectl**：客户端，向集群的 API Server 发出请求。

`docker ps` 通常看到的是 Minikube 节点容器，不会逐个列出其中的 Kubernetes 应用 Pod。查询应用要使用 `kubectl get pods`。

一个节点可以同时运行控制平面和应用。Minikube 的单节点环境支持这样使用，足以完成第一周练习。

## 4. 认识请求经过哪些组件

```text
kubectl 提交 Deployment
        ↓
API Server 接收请求；集群状态存储在 etcd
        ↓
Deployment / ReplicaSet 控制器通过 API 协调所需的 Pod
        ↓
Scheduler 为尚未分配节点的 Pod 选择节点
        ↓
该节点上的 kubelet 调用容器运行时启动容器
```

这是一张理解职责的简化图。组件通过 API 观察、更新状态，实际是异步协调，不是一个进程依次直接调用所有组件。

今天先记住：**API Server 是入口；etcd 存状态；控制器做协调；Scheduler 选节点；kubelet 在节点上落实 Pod。**

## 5. 优先检查已有环境

2026-09-24 编写时已确认：Minikube v1.38.1，profile 为 `minikube`，Docker 驱动，Kubernetes v1.35.1，节点 Ready。kubectl 客户端为 v1.36.2。集群还有其他应用，本教程不要求重建它。

你现在在 Mac 终端逐条执行：

```bash
# 先在终端进入本仓库根目录
uname -m
minikube version
minikube profile list
minikube status -p minikube
kubectl config get-contexts
kubectl config current-context
```

正常的原生 Apple Silicon 终端输出 `arm64`。Minikube 状态应类似：

```text
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

profile 是 Minikube 管理本地集群的名称；context 是 kubectl 选用的连接设置。它们在本例中恰好都叫 `minikube`。

如果上述状态正常，直接进入第 6 节，跳过下面的安装与启动分支。

### 仅在环境没有运行时

先启动 Docker Desktop，等待它显示引擎就绪：

```bash
open -a Docker
docker version
```

`docker version` 应同时有 Client 和 Server 信息。确认 profile 已存在后，用下面的命令启动同一个集群：

```bash
minikube start -p minikube
```

如果工具本身缺失，有 Homebrew 时可以安装缺少的项：

```bash
brew install minikube
brew install kubectl
```

没有 Docker Desktop 时，从 [官方安装页](https://docs.docker.com/desktop/setup/install/mac-install/) 选择 Apple silicon 版本。没有 Homebrew 时，先按 [官网](https://brew.sh/) 安装及配置 PATH。

**仅在 `minikube profile list` 确认没有已有集群时**，首次创建可参考：

```bash
minikube start -p minikube --driver=docker --cpus=2 --memory=4096
```

这里的 4GB 是给学习节点的预算，Docker Desktop 的虚拟机内存还需要留出余量。你已有可用集群，不需要执行首次创建分支，也不要为了调整资源而直接删除集群。

## 6. 确认节点与系统组件

```bash
kubectl config use-context minikube
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl version
```

`context` 通常关联集群、访问身份和默认命名空间。先确认它，可以避免在错误集群里操作。

节点输出类似下面，运行时间和 IP 可以不同：

```text
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   ...   v1.35.1
```

在 `kube-system` 中找出 `kube-apiserver`、`kube-scheduler`、`kube-controller-manager`、`etcd`。CoreDNS 负责集群内 DNS，后面会用到。今天先观察，不修改这些系统组件。

`kubectl version` 的客户端与服务端次版本应相差不超过 1。当前客户端 1.36、服务端 1.35 在支持范围内；不需要为本课升级现有集群。[版本要求](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)

## 7. 小探索：把命令和对象对应起来

```bash
kubectl get namespaces
kubectl get deployments -A
kubectl get pods -A
```

`-A` 表示所有命名空间。你会看见之前创建的其他应用，这正是本教程要使用专门命名空间的原因。只观察，不删除。

在纸上画出「Mac → Docker Desktop → Minikube 节点 → Pod → 容器」，再用另一条箭头画出 kubectl 向 API Server 发请求。能画出来就不容易混淆工具与集群。

## 8. 今天的验收

- [ ] Minikube 的 host、kubelet、apiserver 都是 Running。
- [ ] 当前 context 是 `minikube`。
- [ ] 节点是 Ready。
- [ ] 能解释 Docker Desktop、Minikube 和 kubectl 的分工。
- [ ] 能用自己的话解释「保持两个副本运行」。

思考：关闭 Docker Desktop 后，kubectl 还能访问这个集群吗？重新启动后应该先检查什么？见 [参考答案](answers.md)。

完成后，把版本和遇到的问题记到 [学习记录](progress.md)。保留集群，明天继续。

资料：[Minikube 入门](https://minikube.sigs.k8s.io/docs/start/) · [集群组件](https://kubernetes.io/docs/concepts/overview/components/)
