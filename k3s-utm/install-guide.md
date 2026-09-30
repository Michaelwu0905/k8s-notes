# 从三台 UTM Ubuntu 虚拟机搭建 K3s：完整实操记录

本文记录 **2026-09-30 已实际完成**的一次安装：Apple Silicon Mac 上三台 UTM Ubuntu VM，组成一台 K3s Server 加两台 Agent 的学习集群。文中的 IP、网卡和 K3s 版本来自这次安装，不是通用默认值。

> **当前三台 VM 已经安装完成。** 第 1～5 步供以后用全新 VM 或快照重建时照做；现在想练习，请从[第 6 步](#第-6-步从-mac-管理集群)开始。安装脚本会拒绝覆盖已有 K3s 配置。

## 先认识这套环境

| SSH 别名和 Kubernetes Node 名称 | 角色 | UTM 私网 IP | 实测资源 |
| --- | --- | --- | --- |
| `k3s-master` | 唯一 Server；控制平面，也能运行 Pod | `192.168.64.4` | 2 vCPU、约 2.6 GiB 内存 |
| `k3s-worker-1` | Agent；运行工作负载 | `192.168.64.2` | 2 vCPU、约 1.6 GiB 内存 |
| `k3s-worker-2` | Agent；运行工作负载 | `192.168.64.5` | 2 vCPU、约 1.6 GiB 内存 |

三台 VM 均为 Ubuntu 26.04.1 LTS、ARM64，位于 UTM 的 `192.168.64.0/24` 私网。Mac 的 `~/.ssh/config` 已配置上述三个 SSH 别名和免密登录。这里用 UTM 的共享网络，不需要给 VM 安装 Tailscale；Mac 可通过 VM 私网 IP 访问 K3s API。[UTM 网络模式](https://docs.getutm.app/settings-qemu/devices/network/network/)

```text
Mac：kubectl + 独立 kubeconfig
               │ TCP 6443
               ▼
k3s-master（192.168.64.4）── K3s Server + SQLite
       │                         │
       ├── k3s-worker-1（.2）───┤ K3s Agent + Flannel VXLAN
       └── k3s-worker-2（.5）───┘
```

K3s 支持 ARM64；Server 最低要求 2 核 / 2 GB，Agent 最低 1 核 / 512 MB，**不含业务负载**。节点之间需要 TCP 6443（Agent → Server）、UDP 8472（默认 VXLAN，节点互通），metrics-server 等功能还使用 TCP 10250。这三个端口只需在本机虚拟网络内互通；不要把 UDP 8472 暴露到公网。[K3s 要求与端口](https://docs.k3s.io/installation/requirements)

**约定：**除非另有说明，本教程的命令在 **Mac 终端、本仓库根目录**运行；文中的 `ssh k3s-master` 会标明进入 VM 终端的时刻。复制命令前先看自己所在的终端。重建新 VM 时，先核对它们的真实 IP 和网卡名，不能盲目沿用 `.4`、`.2`、`.5` 和 `enp0s1`。

## 第 1 步：确认三台 VM 和网络

在 **Mac 终端**检查三个 SSH 别名，观察主机名、IP、架构、内存和根分区：

```bash
for host in k3s-master k3s-worker-1 k3s-worker-2; do
  echo "[$host]"
  ssh "$host" 'hostname; uname -m; ip -4 -br addr; free -h; df -h /; sudo -n true'
done
```

本次实际看到的私网网卡均为 `enp0s1`，IP 如上表。`k3s-worker-1` 的 Ubuntu 主机名原本是 `ubuntu`；K3s 配置里的 `node-name` 会明确设成 `k3s-worker-1`，避免与其他 VM 重名。节点名称必须唯一。[K3s 节点要求](https://docs.k3s.io/installation/requirements)

再确认三台 VM 互相能连通。以下从两个 Agent 测试到 Server：

```bash
ssh k3s-worker-1 'ping -c 2 192.168.64.4'
ssh k3s-worker-2 'ping -c 2 192.168.64.4'
```

本次安装前还核对了三台机器彼此的 ping、安装脚本 `https://get.k3s.io` 可达、UFW 为 `inactive`，并确认未安装旧 K3s。若你的新 VM 启用了防火墙，先按上面的官方端口要求放行**VM 私网**流量。默认 Pod / Service 网段分别为 `10.42.0.0/16` / `10.43.0.0/16`，也要避免与已有网络冲突。

## 第 2 步：准备磁盘与 swap

这三台 VM 的虚拟磁盘分别为 20、25、20 GB，但 Ubuntu 初装时根逻辑卷只分到约 10、11、10 GB；每台根分区最初仅余约 4 GB。我们把卷组里**已经存在但尚未分配**的空间扩给根卷，完成后根分区约为 17、22、17 GB。此操作会扩大文件系统，**不适合作为可随意撤销的练习**；若是别的机器，先看清自己的 `lsblk` 和 LVM 布局。

当时三台 VM 也都启用了 `/swap.img`。Kubernetes 默认 kubelet 遇到启用的 swap 会拒绝启动，所以需要关闭当前 swap，并在 `/etc/fstab` 注释掉自动启用的条目。[Kubernetes swap 说明](https://kubernetes.io/docs/concepts/cluster-administration/swap-memory-management/)

这一步的实现放在 [`prepare-node.sh`](prepare-node.sh)：它先检查 `ubuntu-vg` 是否有空闲 extent，再对 `/dev/ubuntu-vg/ubuntu-lv` 执行 `lvextend -l +100%FREE -r`；随后运行 `swapoff -a`，备份 `/etc/fstab` 为 `/etc/fstab.before-k3s`，并注释 swap 行。在 **Mac 终端、全新 VM 上**依次运行：

```bash
for host in k3s-master k3s-worker-1 k3s-worker-2; do
  ssh "$host" 'bash -se' < k3s-utm/prepare-node.sh
done
```

预期每台命令最后显示扩展后的 `df -h /`；`swapon --show` **没有输出**。脚本针对本次 VM 的 LVM 名称编写，其他磁盘布局不要直接照搬。安装后复查：

```bash
ssh k3s-master 'df -h /; swapon --show'
ssh k3s-worker-1 'df -h /; swapon --show'
ssh k3s-worker-2 'df -h /; swapon --show'
```

## 第 3 步：在 master 安装唯一 Server

Server 提供 Kubernetes API、调度和集群数据。这里**只安装一台 Server**，使用 K3s 默认 SQLite；两个 worker 是 Agent，不搭建三 Server etcd HA。K3s Server 本身也包含 Agent 功能，所以它会出现在 `kubectl get nodes` 中。[K3s 快速入门](https://docs.k3s.io/quick-start)

安装脚本 [`install-server.sh`](install-server.sh) 会从 `enp0s1` 读取 `192.168.64.4`，生成一个专供 Agent 加入的令牌文件，并写入 `/etc/rancher/k3s/config.yaml`。本次实际配置如下，**没有把令牌值写进 YAML**：

```yaml
node-name: "k3s-master"
node-ip: "192.168.64.4"
advertise-address: "192.168.64.4"
tls-san:
  - "192.168.64.4"
flannel-iface: "enp0s1"
agent-token-file: /etc/rancher/k3s/agent-token
```

`node-ip` 是节点向集群公布的 VM 私网地址；`advertise-address` 是 API Server 公布的地址；`tls-san` 让 Mac 通过这个 IP 访问 API 时证书匹配；`flannel-iface` 固定 Pod 跨节点流量使用的 VM 网卡；`agent-token-file` 指向 Server 上 root 可读的 Agent 令牌。[Server 配置参数](https://docs.k3s.io/cli/server) · [配置文件用法](https://docs.k3s.io/installation/configuration)

在 **Mac 终端、全新 master VM 上**执行：

```bash
ssh k3s-master 'bash -se -- k3s-master' < k3s-utm/install-server.sh
```

脚本从 `https://get.k3s.io` 下载官方安装脚本，作为 systemd 服务安装并启动 K3s。本次官方 stable 通道安装到 `v1.36.4+k3s1`。以后重建时 stable 版本可能改变；**两个 Agent 必须使用与当时 Server 相同的完整版本**。安装刚结束的一瞬间，`get nodes` 可能暂时显示 `No resources found`，等初始化完成再检查：

```bash
ssh k3s-master 'sudo systemctl is-active k3s; sudo k3s --version; sudo k3s kubectl get nodes -o wide'
```

预期 `k3s` 服务为 `active`，`k3s-master` 最终为 `Ready`，`INTERNAL-IP` 为 `192.168.64.4`。系统 Pod 拉取镜像可能还需要一些时间。

## 第 4 步：把专用 Agent 令牌交给两个 worker

K3s 用令牌认证新节点。Server 使用 `agent-token-file` 单独生成 Agent 令牌；Agent 端则用 `token-file` 从 root 可读文件加载。**不要把令牌粘贴到聊天、文档或命令行参数中。** K3s 安装后可在 Server 的 `/var/lib/rancher/k3s/server/agent-token` 找到供 Agent 使用的令牌文件。[K3s 令牌说明](https://docs.k3s.io/cli/token)

下面的命令在 **Mac 终端**运行。它通过两段加密 SSH 连接把令牌从 Server 的标准输出直接送入 worker 的 root 文件，全程不在终端打印令牌：

```bash
set -o pipefail
ssh k3s-master 'sudo cat /var/lib/rancher/k3s/server/agent-token' \
  | ssh k3s-worker-1 'sudo install -d -m 700 /etc/rancher/k3s && sudo sh -c "umask 077; cat > /etc/rancher/k3s/join-token"'

ssh k3s-master 'sudo cat /var/lib/rancher/k3s/server/agent-token' \
  | ssh k3s-worker-2 'sudo install -d -m 700 /etc/rancher/k3s && sudo sh -c "umask 077; cat > /etc/rancher/k3s/join-token"'
```

两条管道命令成功时没有输出。`set -o pipefail` 让前一段 SSH 失败时整条管道也报错。若是新开的终端，重新执行该行后再复制两条管道命令。

## 第 5 步：安装两个 Agent

Agent 需要 Server 的私网 API 地址、刚复制的令牌文件、自己的唯一 Node 名称。`k3s-worker-1` 的实际配置为：

```yaml
node-name: "k3s-worker-1"
node-ip: "192.168.64.2"
flannel-iface: "enp0s1"
server: "https://192.168.64.4:6443"
token-file: /etc/rancher/k3s/join-token
```

`k3s-worker-2` 只把 `node-name` 和 `node-ip` 换为 `k3s-worker-2`、`192.168.64.5`。[`install-agent.sh`](install-agent.sh) 会自动读取本机网卡 IP，写入配置，并用传入的完整 K3s 版本安装 Agent。[Agent 配置参数](https://docs.k3s.io/cli/agent)

先在 **Mac 终端**查看当前 Server 版本：

```bash
ssh k3s-master 'sudo k3s --version'
```

本次是 `v1.36.4+k3s1`。**重建时请替换以下两条命令里的版本和 Server IP**，然后执行：

```bash
ssh k3s-worker-1 'bash -se -- k3s-worker-1 192.168.64.4 v1.36.4+k3s1' < k3s-utm/install-agent.sh
ssh k3s-worker-2 'bash -se -- k3s-worker-2 192.168.64.4 v1.36.4+k3s1' < k3s-utm/install-agent.sh
```

每条命令末尾应显示 Agent 的 K3s 版本和 `active`。回到 Server 检查三节点：

```bash
ssh k3s-master 'sudo k3s kubectl get nodes -o wide'
```

本次验证结果：三台都为 `Ready`，版本均为 `v1.36.4+k3s1`，`INTERNAL-IP` 分别是 `.4`、`.2`、`.5`。如果 Agent 初装后暂时 `NotReady`，先给它少量时间拉取系统镜像，再看后面的排障表。

## 第 6 步：从 Mac 管理集群

K3s 在 Server 上生成 `/etc/rancher/k3s/k3s.yaml`。该文件拥有**集群管理员权限**，其默认 `server` 地址是 `https://127.0.0.1:6443`，只适合在 Server VM 本机使用。Mac 需要一份单独保存、把地址改为 `https://192.168.64.4:6443` 的副本。[K3s 集群访问](https://docs.k3s.io/cluster-access)

在 **Mac 终端**运行一次 [`setup-kubeconfig-mac.sh`](setup-kubeconfig-mac.sh)：

```bash
bash k3s-utm/setup-kubeconfig-mac.sh
```

脚本会从 `k3s-master` 的 `enp0s1` 读取当前 IP，通过 SSH 获取管理员配置并改写 Server 地址，用仅本人可读的权限保存到 `~/.kube/k3s-utm.yaml`，再尝试执行 `get nodes`。它**拒绝覆盖已有文件**；当前这台 Mac 已经完成此步骤，不必再运行。以后明确指定 kubeconfig：

```bash
kubectl --kubeconfig ~/.kube/k3s-utm.yaml get nodes -o wide
kubectl --kubeconfig ~/.kube/k3s-utm.yaml get pods -A -o wide
kubectl --kubeconfig ~/.kube/k3s-utm.yaml top nodes
```

这不会改变 `~/.kube/config` 中的其他集群设置。不要把 `k3s-utm.yaml` 放进 Git 仓库。VM 重建、证书或 Server IP 变化后，重新从 Server 获取并更新它，不能继续使用旧副本。

## 第 7 步：验证真正的跨节点 Pod 网络

`get nodes` 全为 Ready，只能说明节点已加入；还要用 Pod 流量验证网络。[`smoke.yaml`](smoke.yaml) 创建：

- `k3s-lab` 命名空间；
- `web` Nginx Pod，固定在 worker-1；
- `web` ClusterIP Service；
- `client-worker-2` 和 `client-master` 两个 BusyBox Pod，分别固定在 worker-2 和 master。

在 **Mac 终端**执行（当前集群已经执行过，`apply` 可以重复运行）：

```bash
kubectl --kubeconfig ~/.kube/k3s-utm.yaml apply -f k3s-utm/smoke.yaml
kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab wait --for=condition=Ready pod --all --timeout=240s
kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab get pods -o wide
kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab get svc web
```

`get pods -o wide` 应显示三个 Pod 位于三台不同 VM。接着从两个客户端访问服务：

```bash
kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab exec client-worker-2 -- wget -qO- -T 10 http://web:80
kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab exec client-master -- wget -qO- -T 10 http://web:80
```

两次请求本次均返回 `Welcome to nginx!` 页面。路径包括 `web` 的集群 DNS 解析、Service 转发，以及从 worker-2 / master 到 worker-1 的跨节点 Pod 网络。测试文件用 `nodeName` 固定 Pod 只是为了保证跨节点，不是日常部署工作负载的推荐方式。

实验后如果想清理测试资源：

```bash
kubectl --kubeconfig ~/.kube/k3s-utm.yaml delete namespace k3s-lab
```

这仅删除 `k3s-lab` 中的实验 Pod 和 Service，不会卸载集群。

## 常见问题与复查命令

| 现象 | 先执行什么 | 常见原因 |
| --- | --- | --- |
| Mac 的 `kubectl` 连不上 | `ssh k3s-master 'ip -4 -br addr show enp0s1; sudo systemctl is-active k3s'` | Server VM 关闭、UTM DHCP 改了 IP、kubeconfig 中仍是旧地址 |
| Server 安装后暂时看不到 Node | `ssh k3s-master 'sudo journalctl -u k3s -n 100 --no-pager'` | 刚启动还在初始化或拉镜像；本次刚安装后曾短暂出现 `No resources found` |
| Agent 不为 Ready | `ssh k3s-worker-1 'sudo systemctl status k3s-agent --no-pager; sudo journalctl -u k3s-agent -n 100 --no-pager'` | 令牌、版本、Server IP 或私网连接问题 |
| Pod 一直 Pending / 拉镜像失败 | `kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab describe pod web` | 资源不足、镜像仓库不通、镜像不支持 ARM64 |
| 跨节点 Service 不通 | `kubectl --kubeconfig ~/.kube/k3s-utm.yaml -n k3s-lab get pods -o wide` | Pod 实际位置、CoreDNS、Flannel UDP 8472 或防火墙问题 |
| 资源吃紧 | `kubectl --kubeconfig ~/.kube/k3s-utm.yaml top nodes` | 三台 VM 与 Minikube 同时占用 Mac 的 16 GB 内存；练习三节点时可先停 Minikube |

本次保留了 K3s 默认的 CoreDNS、Traefik、ServiceLB、metrics-server 和本地存储，因此可以继续练 Service、Ingress、指标和 PVC；Traefik/ServiceLB 默认会在节点使用 80/443 端口。[K3s 网络服务说明](https://docs.k3s.io/networking/networking-services)

这套实验集群只有一个 Server，Mac 睡眠或 VM 关闭时不会保持在线。它适合学习 Kubernetes 对象、网络和排障。备考 CKA 时还需要另外练 **kubeadm** 建群、升级和维护；K3s 的一键安装方式不能代替该部分。[CKA 官方考纲](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
