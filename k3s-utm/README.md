# UTM 三节点 K3s 练习环境

这套环境已于 2026-09-30 在你的三台 UTM Ubuntu VM 上安装并验证。Mac 上的 Minikube 配置没有被覆盖；K3s 管理员 kubeconfig 单独保存在 `~/.kube/k3s-utm.yaml`，**不要提交或分享该文件**。

想了解从零搭建的全部步骤，请看[三台 UTM 虚拟机安装 K3s 的详细教程](install-guide.md)。

| SSH 别名 / Node 名称 | 角色 | 当前 UTM 私网 IP | VM 内存 | 安装后状态 |
| --- | --- | --- | --- | --- |
| `k3s-master` | 唯一 Server、控制平面，也可运行 Pod | `192.168.64.4` | 约 2.6 GiB | Ready |
| `k3s-worker-1` | Agent | `192.168.64.2` | 约 1.6 GiB | Ready |
| `k3s-worker-2` | Agent | `192.168.64.5` | 约 1.6 GiB | Ready |

三台都是 Ubuntu 26.04.1 LTS / ARM64，K3s 版本一致：`v1.36.4+k3s1`。各 VM 在 UTM 的 `192.168.64.0/24` 私网内互通，UFW 当前未启用。Server 使用默认 SQLite 数据库、Flannel VXLAN 网络；保留默认 CoreDNS、Traefik、ServiceLB、metrics-server 和本地存储组件。K3s Server 同时也运行 Agent，所以可以承载 Pod。[K3s 快速入门](https://docs.k3s.io/quick-start) · [网络要求](https://docs.k3s.io/installation/requirements)

## 现在就开始

在 **Mac 终端**使用独立 kubeconfig，避免误操作其他集群：

```bash
kubectl --kubeconfig ~/.kube/k3s-utm.yaml get nodes -o wide
kubectl --kubeconfig ~/.kube/k3s-utm.yaml get pods -A -o wide
kubectl --kubeconfig ~/.kube/k3s-utm.yaml top nodes
```

在 **Server VM 终端**也可以直接使用内置 kubectl：

```bash
ssh k3s-master
sudo k3s kubectl get nodes -o wide
```

`k3s-master` 停机时，API Server 会不可用；它启动并恢复后，两个 Agent 会重新连接。三台 VM 都运行在同一台 Mac 上，因此这不是高可用环境。Mac 睡眠或 UTM 关机时，集群也会暂停。

## 已完成的跨节点实验

[`smoke.yaml`](smoke.yaml) 建立了 `k3s-lab` 命名空间：Nginx Pod 在 worker-1，两个客户端分别在 worker-2 与 master，通过 `web` 这个 ClusterIP Service 访问它。已经验证两个客户端都收到 Nginx 欢迎页，说明这两条路径的 Pod、Service、DNS 和 Flannel 通信可用。

可自行复查：

```bash
kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab get pods -o wide
kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab get svc web
kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab exec client-worker-2 -- wget -qO- -T 10 http://web:80
```

测试 Pod 用 `nodeName` 固定到各 VM，目的是验证跨节点网络；平时部署应用，让调度器决定节点，或使用 `nodeSelector` / 亲和性等调度规则。若想清理这个实验，执行：

```bash
kubectl --kubeconfig ~/.kube/k3s-utm.yaml delete namespace k3s-lab
```

这只删除测试命名空间，不会卸载 K3s。

## 下一步练习顺序

1. **认识节点和系统组件**：比较 `get nodes -o wide`、`get pods -A -o wide`、`top nodes` 的结果；找出 CoreDNS、Traefik、ServiceLB 分别运行在哪台 VM。
2. **Service 与 DNS**：先预测 `smoke.yaml` 中客户端请求 `http://web:80` 的路径，再从 worker-2 执行上面的 `wget`；查看 `kubectl -n k3s-lab get endpointslice`。
3. **调度与故障**：在一个新命名空间创建 Deployment，观察 Pod 被调度到哪台 VM；尝试 cordon / drain 一个 Agent，记录 Pod 的变化，再 uncordon。不要从存有重要数据的 Pod 开始练。
4. **存储与入口**：用默认 `local-path` StorageClass 创建 PVC；部署一个简单 Ingress，观察 Traefik 和 ServiceLB。默认 Traefik 会在三台节点上使用 80/443 端口。[K3s 网络服务](https://docs.k3s.io/networking/networking-services)
5. **排障**：观察 `kubectl describe pod`、Events，以及 VM 内的 `sudo journalctl -u k3s` / `sudo journalctl -u k3s-agent`；练习从现象追踪到组件。

这套 K3s 环境适合练日常对象、网络、存储和排障。你的 CKA 目标还要求练习用 **kubeadm** 创建和管理集群，后续应在 VM 快照或另一组 VM 上单独练；K3s 的安装和组件打包方式不能替代 kubeadm。[CKA 官方考纲](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)

## 本次安装做了什么

安装前，三台 VM 都启用了 swap，根逻辑卷只用了虚拟磁盘的一部分。运行 [`prepare-node.sh`](prepare-node.sh) 后，根分区分别扩展到约 17 / 22 / 17 GiB，并关闭 swap、注释 `/etc/fstab` 中的 swap 项；原文件备份为 `/etc/fstab.before-k3s`。默认 kubelet 遇到启用的 swap 会拒绝启动。[Kubernetes swap 说明](https://kubernetes.io/docs/concepts/cluster-administration/swap-memory-management/)

接着在 master 上运行 [`install-server.sh`](install-server.sh)，为 K3s 指定唯一节点名、内网 IP 和 Flannel 网卡，并建立专用 Agent 令牌。两个 worker 使用令牌文件和 [`install-agent.sh`](install-agent.sh) 加入。令牌只存放在 VM 的 root 可读目录，未放进此教程。Mac 的 [`setup-kubeconfig-mac.sh`](setup-kubeconfig-mac.sh) 从 master 获取管理员配置，替换其中的 `127.0.0.1` 为 VM IP，保存在 `~/.kube/k3s-utm.yaml`；这个脚本默认拒绝覆盖已有文件。安装脚本和配置文件的用法见 [K3s 官方配置说明](https://docs.k3s.io/installation/configuration)。

这些安装脚本面向**全新的同类 UTM VM**。当前集群已经装好，不要在它上面重复运行。若将来重新建 VM，先确认 SSH 别名、网卡名 `enp0s1` 和 Server IP，再按“准备节点 → Server → 传 Agent 令牌 → Agent → kubeconfig → 跨节点测试”的顺序操作。

## 遇到问题时

| 现象 | 先检查 |
| --- | --- |
| Mac 无法访问 API | `ssh k3s-master`、`ip -4 -br addr show enp0s1`、`sudo systemctl status k3s`；UTM 的 DHCP IP 是否改变 |
| Agent `NotReady` | 对应 VM 是否在运行；`sudo systemctl status k3s-agent`、`sudo journalctl -u k3s-agent -n 100 --no-pager` |
| Pod 跨节点不通 | 三台 VM 互相 ping；节点 IP、Flannel UDP 8472、防火墙和 `kubectl get pods -o wide` |
| Pod `Pending` / 镜像拉取失败 | `kubectl describe pod` 的 Events；资源余量、镜像仓库可达性、ARM64 镜像支持 |
| 磁盘或内存吃紧 | `kubectl top nodes`、各 VM 的 `free -h` 和 `df -h /`；同时运行 Minikube 时可先 `minikube stop` |

UTM Shared Network 的地址来自虚拟网络的 DHCP。当前 IP 已用于 Server 与 Agent 配置，若重建 VM 或 UTM 分配新地址，需要同步检查 K3s 配置与 Mac kubeconfig；不要只修改 `~/.ssh/config`。[UTM 网络模式](https://docs.getutm.app/settings-qemu/devices/network/network/)
