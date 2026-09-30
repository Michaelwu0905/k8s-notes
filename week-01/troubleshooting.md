# 第一周常见问题：UTM K3s 环境

[目录](README.md) · [命令速查](cheatsheet.md)

遇到问题，先保留**完整命令、错误、所用 kubeconfig、Namespace 和 Pod 所在节点**。本页命令默认在 Mac、本仓库根目录执行；每个新终端先运行：

```bash
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
```

## 1. kubectl 报 localhost:8080 connection refused

这通常说明当前终端没有读到本集群的 kubeconfig。Mac 的默认 `~/.kube/config` 不包含这套 K3s 配置时，kubectl 可能尝试连接 `http://localhost:8080`。

```bash
printf '%s\n' "$KUBECONFIG"
ls -l "$HOME/.kube/k3s-utm.yaml"
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl config current-context
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'
kubectl get nodes -o wide
```

这个文件内的 context 名是 `default`，要同时核对 API 地址和 `k3s-master`、两个 worker 的节点名。`export` 只对当前终端有效，开新终端或在 IDE 里运行时要重新设置。单条命令也可加 `--kubeconfig "$HOME/.kube/k3s-utm.yaml"`。不要用 `sudo kubectl` 掩盖配置问题，也不要把 kubeconfig 上传到仓库。

## 2. 配置正确，但 API 超时或拒绝连接

先确认三台 VM 在 UTM 中运行，再从 Mac 检查 SSH 与服务：

```bash
ssh k3s-master 'sudo systemctl is-active k3s'
ssh k3s-worker-1 'sudo systemctl is-active k3s-agent'
ssh k3s-worker-2 'sudo systemctl is-active k3s-agent'
```

若 master 无法 SSH，检查 UTM 是否启动、Mac 是否刚从睡眠恢复。若 `k3s` 不是 `active`，到 master 看 `sudo systemctl status k3s` 和 `sudo journalctl -u k3s -n 100 --no-pager`。Agent 异常时在对应 worker 看 `k3s-agent` 的状态和日志。初学阶段先记录错误，不要直接卸载重装。

UTM Shared Network 的 DHCP 地址可能变化。若 SSH 仍可连接但 kubeconfig 的 API 地址不可达，对照下面两项：

```bash
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'
ssh k3s-master 'ip -4 -br addr show enp0s1'
```

地址变化可能还涉及 K3s Server/Agent 的节点 IP 与加入地址；按 [UTM 集群安装说明](../k3s-utm/install-guide.md) 检查整套配置，不要只改 Mac kubeconfig。

## 3. command not found 或 Namespace NotFound

在 Mac 检查 `command -v kubectl`；缺失时按 [macOS 安装 kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/) 安装。SSH 命令在 Mac 执行；`systemctl` 则运行在 Ubuntu VM，不在 macOS 上运行。

```bash
kubectl get namespaces
kubectl get pods -A
kubectl apply -f week-01/manifests/namespace.yaml
```

`-n cka-w1` 与 `-n default` 是不同范围。若对象 `AlreadyExists`，先 `get` / `describe` 确认归属；不要因此删掉其他人的对象。第 2 天用 `create`，之后的 YAML 用 `apply` 管理。

## 4. rollout status 超时 / RunContainerError

超时说明 Deployment 尚未达到可用副本数，先查 Pod，而不是只增加 `--timeout`：

```bash
kubectl get deployment,pods -n cka-w1 -o wide
kubectl describe pod -n cka-w1 -l app=hello
```

若 Events 包含 `exec: "replicas=1": executable file not found`，并且 `describe` 显示容器 `Command: replicas=1`，说明它被当作启动命令，Nginx 根本没启动。创建命令中的 `--replicas=1` 是一个完整参数；写成 `-- replicas=1` 就变成了容器命令。第 2 天创建一个副本时可以直接省略这个参数，因为默认就是 1。

对于本课 `hello` Deployment，可以移除误设的命令，然后重新等待：

```bash
kubectl patch deployment hello -n cka-w1 --type=json -p='[{"op":"remove","path":"/spec/template/spec/containers/0/command"}]'
kubectl rollout status deployment/hello -n cka-w1 --timeout=180s
```

这条补丁只适用于已确认 `hello` 容器存在这个错误 `command` 字段的情况。若 Events 显示拉镜像、资源不足或其他错误，按对应小节排查。

## 5. ImagePullBackOff / ErrImagePull

先找到失败的 Pod 和它的节点，再读 Events：

```bash
kubectl get pods -n cka-w1 -o wide
kubectl describe pods -n cka-w1 -l app=web
kubectl get events -n cka-w1 --sort-by=.metadata.creationTimestamp
```

| 事件线索 | 先检查 |
| --- | --- |
| `manifest unknown` / `not found` | 仓库名、标签是否存在 |
| `unauthorized` / `denied` | 仓库认证 |
| `timeout` / DNS / TLS 错误 | **该 Pod 所在 VM** 的网络、DNS、代理 |
| `toomanyrequests` | 仓库限流 |
| `no matching manifest` | 镜像是否提供 Linux ARM64 版本 |

Mac 的 Docker 镜像与三台 VM 的 K3s/containerd 镜像仓库相互独立。Mac 能 `docker pull` 不代表节点已经有镜像。可以在对应 VM 上用 `sudo k3s crictl images` 查看本地镜像；需要时检查 `sudo journalctl -u k3s-agent -n 100 --no-pager`（master 上改为 `-u k3s`）。镜像可能调度到其他 VM，不能只检查 master。本周镜像为 `nginx:1.30.5-alpine` 和 `busybox:1.37.0`。第 6 天故意使用错误标签，但现实故障要以 Events 为准。

## 6. Pending / ContainerCreating / NotReady

```bash
kubectl get nodes -o wide
kubectl get pods -n cka-w1 -o wide
kubectl describe pods -n cka-w1 -l app=web
kubectl top nodes
```

若节点 `NotReady`，先检查对应 UTM VM 和 `k3s`/`k3s-agent` 服务。`Insufficient cpu` 或 `Insufficient memory` 表示当前可调度资源不足；先恢复本课基线：2 个 `web` Pod、1 个 `toolbox`，并查看 VM 实际内存。`ContainerCreating` 也可能卡在镜像、网络沙箱或卷准备，具体看 Events。当前 K3s 装有 metrics-server；若 `kubectl top` 暂时失败，先用 `describe`、Events 和 VM 上的 `free -h`，不妨碍本周练习。

## 7. CrashLoopBackOff

这表示容器启动后反复退出。与镜像尚未拉取不同，应结合退出原因和日志判断。

```bash
kubectl get pods -n cka-w1 -o wide
kubectl describe pods -n cka-w1 -l app=web
kubectl logs deployment/web -n cka-w1 --tail=50
```

若要查上一次容器运行的日志，先从 `get pods` 复制实际 Pod 名称，再执行 `kubectl logs 实际Pod名 -n cka-w1 --previous`。容器从未重启时没有 previous 日志属正常。本周不用主动制造这种故障。

## 8. YAML 报错

检查缩进、冒号、`apiVersion`、`kind`，以及 selector 与 Pod labels 是否匹配。命令在仓库根目录运行，文件路径才会如教程所示。可让服务端验证而不保存修改：

```bash
kubectl apply --dry-run=server -f week-01/manifests/web-deployment.yaml
```

这需要连接集群，且 `cka-w1` 已存在。Deployment selector 等字段不可变；第 3 天只修改副本数。

## 9. Mac 的 8080 端口访问失败

先确认运行 `port-forward` 的终端仍在运行、该终端设置了 `KUBECONFIG`、输出出现 `Forwarding from ...`，并核对 curl 使用的本地端口。若 8080 被占用，在该终端改用：

```bash
kubectl port-forward -n cka-w1 service/web 8081:80
```

再访问 `http://127.0.0.1:8081`。被转发的 Pod 删除或替换后，通道可能中断，重新启动即可。`port-forward` 成功不证明普通 Service 路径正常。

## 10. Pod Running，但 Service 不通

```bash
kubectl get pods -n cka-w1 -l app=web --show-labels -o wide
kubectl describe service web -n cka-w1
kubectl get endpointslices -n cka-w1 -l kubernetes.io/service-name=web -o yaml
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

先比对 Service selector 和 Pod 标签，再比对 `targetPort` 与应用实际监听端口。`get pods -o wide` 可显示客户端与后端在哪台 VM；跨节点失败时再结合节点、Flannel 和 VM 网络排查。[K3s 安装说明](../k3s-utm/install-guide.md)记录了这套环境的跨节点验证。

## 11. 恢复本周正常基线

确认 `KUBECONFIG` 和三个节点，结束先前的端口转发，然后按顺序应用：

```bash
kubectl apply -f week-01/manifests/namespace.yaml
kubectl apply -f week-01/manifests/web-deployment.yaml
kubectl apply -f week-01/manifests/web-service.yaml
kubectl apply -f week-01/manifests/toolbox-pod.yaml
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
kubectl wait -n cka-w1 --for=condition=Ready pod/toolbox --timeout=180s
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

这些命令不会自动删除额外对象。故障实验留下的 `broken-image` 可在确认归属后单独执行 `kubectl delete deployment broken-image -n cka-w1 --ignore-not-found`。若 `toolbox` 因不可变字段无法重新 apply，只删除本课的 `toolbox` Pod，再应用其 YAML。
