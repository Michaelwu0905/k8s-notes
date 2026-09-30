# 第 1 天：理解 Kubernetes，检查 UTM K3s 集群

[返回本周目录](README.md) · 下一课：[部署与观察](02-workloads.md)

**用时：概念 25 分钟，环境检查 20 分钟，探索与验收 15 分钟。** 今天要确认三台节点都是 Ready，并说清 Mac、UTM、K3s 和 kubectl 的分工。

## 1. 从 Docker 走向 Kubernetes

你可能运行过 `docker run nginx`。这能启动一个容器。当应用需要多个副本、分布在多台机器上、持续更新时，还需要协调这些操作。

Kubernetes 接收你的要求，例如「保持两个 Nginx 副本运行」，再持续观察实际情况并尝试让它符合要求。这叫**期望状态**。若只剩一个副本，控制器会尝试补建；若镜像无法拉取，仍需你查看证据并处理原因。ku

## 2. 五个先要认识的对象

| 名词 | 先这样理解 | 本周例子 |
| --- | --- | --- |
| Cluster，集群 | 共同运行 Kubernetes 的节点 | 三台 UTM VM 组成的 K3s 集群 |
| Node，节点 | 提供 CPU、内存和网络的机器 | `k3s-master`、`k3s-worker-1`、`k3s-worker-2` |
| Pod | Kubernetes 调度的基本单位，包含一个或多个容器 | 一个 Pod 里运行一个 Nginx |
| Deployment | 管理应用副本和更新等期望状态 | 要求 Nginx 保持两个副本 |
| Namespace，命名空间 | 为一部分资源划分名称范围 | `cka-w1` |

一个 Pod 可以有多个紧密协作的容器，共享网络等资源。本周先使用「一个 Pod 一个容器」的简单形式。Namespace 不是虚拟机，也不会自动提供网络隔离。

## 3. 集群实际运行在哪里

```text
Mac：运行 kubectl，读取 ~/.kube/k3s-utm.yaml
  │ 通过 UTM 私网访问 Kubernetes API
  ▼
UTM Ubuntu VM：k3s-master（Server，控制平面 + 工作节点）
  ├─ API Server、调度器、控制器和 SQLite 数据库
  ├─ kubelet、containerd、Flannel
  └─ 可以运行应用 Pod
UTM Ubuntu VM：k3s-worker-1（Agent：kubelet、containerd、Flannel）
UTM Ubuntu VM：k3s-worker-2（Agent：kubelet、containerd、Flannel）
```

**UTM** 提供三台 Linux 虚拟机；**K3s** 在它们上面运行 Kubernetes；**kubectl** 是 Mac 上访问 API Server 的客户端。应用容器运行在 VM 的容器运行时中，不在 Mac 的 Docker 镜像仓库里。

本环境只有一个 Server，默认用 SQLite 保存集群状态。K3s 将若干控制平面组件打包运行，不能假设 `kubectl get pods -n kube-system` 会列出独立的 `kube-apiserver`、`etcd` Pod。三个节点也不代表控制平面高可用：master 停机时 API 不可用。三台 VM 都在同一台 Mac 上，Mac 睡眠时集群也会暂停。

## 4. 请求经过哪些组件

```text
kubectl 提交 Deployment → API Server 接收并保存期望状态
    → 控制器协调所需的 Pod → Scheduler 为 Pod 选择节点
    → 目标节点的 kubelet 通过 containerd 启动容器
```

这只是职责示意，实际通过 API 异步协调，不是这些组件逐个直接调用。今天记住：**API Server 是入口；数据库保存状态；控制器做协调；调度器选节点；kubelet 在节点上落实 Pod。**

## 5. 在 Mac 选对集群

本教程已安装好的管理员 kubeconfig 在 `~/.kube/k3s-utm.yaml`。它与 Mac 默认的 `~/.kube/config` 分开保存，**不要把 kubeconfig 提交到 GitHub**。每打开一个新终端，都先运行：

```bash
# 先在终端进入本仓库根目录
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl config current-context
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'
kubectl get nodes -o wide
```

此文件内的 context 名称是 `default`；**单看 `default` 不能判断连的是哪个集群**，还要核对 API 地址与三个节点名称。当前三个节点均为 `Ready`，角色列显示 master 为 `control-plane`、两个 worker 为 `<none>`；这不影响它们作为 Agent 工作。IP、运行时间和版本以实际输出为准。

`KUBECONFIG` 只在当前终端生效。若遗漏它，Mac 默认配置可能回退到 `http://localhost:8080`，出现 `connection refused`。也可以为单条命令写 `kubectl --kubeconfig "$HOME/.kube/k3s-utm.yaml" get nodes`。不要仅凭 `kubectl config use-context default` 切换，它可能操作的是另一份配置。

## 6. 检查节点与系统组件

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide
kubectl version
```

在 `kube-system` 中找 CoreDNS、Traefik、metrics-server 等 Pod，先只观察。K3s Server 的运行状态需要到 VM 上看：

```bash
ssh k3s-master 'sudo systemctl is-active k3s'
ssh k3s-worker-1 'sudo systemctl is-active k3s-agent'
ssh k3s-worker-2 'sudo systemctl is-active k3s-agent'
```

正常输出是三个 `active`。若 VM 已关机，先在 UTM 启动它，再检查。客户端 `kubectl` 与 API Server 的次版本通常应相差不超过 1；用 `kubectl version` 核对，不要为本课升级集群。

## 7. 小探索

```bash
kubectl get namespaces
kubectl get deployments -A
kubectl get pods -A -o wide
```

`-A` 表示所有命名空间。注意不同 Pod 的 `NODE` 列；默认由调度器决定节点，副本不保证一台一个。本周练习只在 `cka-w1` 和 `cka-w1-check` 中操作，已有的 `k3s-lab` 和系统资源留在原处。

在纸上画出「Mac kubectl → master API Server → 三台节点上的 Pod」，再标出 Server、Agent、SQLite 和 containerd 的位置。

## 8. 今天的验收

- [ ] 三台节点均为 Ready，能区分 Server 和两个 Agent。
- [ ] 知道新终端要先设置 `KUBECONFIG`；能核对 API 地址与节点名。
- [ ] 能解释 Mac、UTM、K3s 和 kubectl 的分工。
- [ ] 能用自己的话解释「保持两个副本运行」。
- [ ] 知道 master 停机和 Mac 睡眠分别会影响什么。

思考：只关闭一台 worker，和关闭 master，有什么不同？见 [参考答案](answers.md)。完成后把观察结果记到 [学习记录](progress.md)。

资料：[K3s 架构](https://docs.k3s.io/architecture) · [K3s 数据存储](https://docs.k3s.io/datastore) · [集群组件](https://kubernetes.io/docs/concepts/overview/components/)
