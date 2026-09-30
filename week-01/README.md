# 第一周：从零部署并理解一个应用

这周只围绕一个小目标展开：**把 Nginx 放进 Kubernetes，访问它，观察它，并修复几个简单故障。**

你已经熟悉 Linux 和 Docker，可以把时间用在 Kubernetes 新增加的概念上。不需要提前掌握 Helm、Ingress、集群升级或复杂网络。

## 一周结束后，你应当能做到

- 说清 Node、Pod、Deployment、Service、Namespace 分别负责什么。
- 检查现有三节点 UTM K3s 集群，并确认操作的是哪个集群。
- 用命令和 YAML 两种方式部署应用，理解「期望状态」。
- 扩缩容，观察删除 Pod 后的自动补建。
- 从 Mac 访问应用，也能从集群内验证 Service。
- 使用 `get`、`describe`、`logs`、`exec` 和事件找到基本故障线索。
- 不照着答案，完成一个新命名空间中的独立部署。

## 时间安排：约 9 小时

| 日期 | 内容 | 时间 | 完成标志 |
| --- | --- | --- | --- |
| 第 1 天 | [概念与环境](01-cluster.md) | 60 分钟 | 三个 Ready 节点 |
| 第 2 天 | [部署与观察](02-workloads.md) | 60 分钟 | 能部署、扩容、观察补建 |
| 第 3 天 | [YAML 与命名空间](03-yaml.md) | 60 分钟 | 能解释并修改一份 Deployment |
| 第 4 天 | [Service 与访问](04-networking.md) | 60 分钟 | Mac 与集群内均能访问应用 |
| 第 5 天 | [休息或补进度](05-review.md) | 可选 | 不新增必学内容 |
| 第 6 天 | [排障工作坊](06-troubleshooting-lab.md) | 180 分钟 | 完成三个故障实验及一次重建 |
| 第 7 天 | [独立验收与复盘](07-assessment.md) | 120 分钟 | 按要求交付并验证应用 |

首次下载镜像可能额外耗时。下载时可以继续阅读概念，环境问题用第 5 天补齐；不必为了赶进度跳过操作。

## 先约定好名称和路径

| 项目 | 本周统一使用 |
| --- | --- |
| 工作目录 | 本仓库根目录 |
| 集群节点 | `k3s-master`、`k3s-worker-1`、`k3s-worker-2` |
| kubeconfig | `~/.kube/k3s-utm.yaml`（不提交到仓库） |
| 此文件内的 context | `default` |
| 日常实验 Namespace | `cka-w1` |
| 第 2 天临时 Deployment | `hello` |
| 第 3 天起的 Deployment / Service | `web` / `web` |
| 集群内测试 Pod | `toolbox` |
| 第 7 天独立验收 Namespace | `cka-w1-check` |

**所有命令默认在 Mac 终端、本仓库根目录运行。** 打开第二个终端后，也先进入这个目录。只有明确写了 `kubectl exec` 的命令，才会把后面的程序放进容器里执行。

每次重新开始学习，先执行：

```bash
# 先在终端进入本仓库根目录
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl config current-context
kubectl get nodes
```

这个 kubeconfig 内的 context 名是 `default`，还要核对 API 地址和三个节点名，不能只凭 context 名判断集群。如果文件不存在或节点不是 Ready，先完成第 1 天的环境检查。本周命令都显式写 `-n`，练习识别命名空间，不修改默认命名空间。现有集群的其他应用继续保留。

## 怎么阅读和练习

1. 先读本节目标，猜测命令会产生什么结果。
2. 一段一段执行命令，检查输出，遇到错误先停在当前步骤。
3. 看到示例输出时，关注状态和数量；Pod 名称后缀、IP、时间和版本不需要完全一致。
4. 完成后关掉教程重做一次，再勾选 [学习记录](progress.md)。

`bash` 代码块也适用于这台 Mac 默认的 zsh。不要复制输出示例作为命令。`-w`、`-f` 日志跟随、`port-forward` 会持续运行，文中会说明何时按 `Ctrl+C`。

## 配套资料

- [命令速查](cheatsheet.md)：用到时查，不要求一次背完。
- [常见问题](troubleshooting.md)：安装、镜像、端口和状态问题。
- [参考答案](answers.md)：做完题或认真尝试后再看。
- [参考 YAML](solutions/assessment.yaml)：第 7 天的完整答案。
- [资料索引与验证说明](references.md)。

本周沿用已运行的三节点 UTM K3s 集群，不需要重复安装 K3s。只运行少量 Nginx 与 BusyBox 容器；若资源不足，先按排查页检查。清理时只删除本课资源，不卸载或重置集群。三台 VM 均运行在同一台 Mac 上，合盖睡眠后要等 VM 和节点恢复 Ready。
