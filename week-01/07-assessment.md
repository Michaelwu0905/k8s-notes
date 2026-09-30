# 第 7 天：独立部署一个新应用

[上一课](06-troubleshooting-lab.md) · [目录](README.md) · [参考答案](answers.md)

**用时：120 分钟：独立操作 60 分钟，验收 30 分钟，复盘 30 分钟。** 这是一份学习验收，不是 CKA 真题或通过率预测。

允许查官方文档、`kubectl explain` 和本周命令速查。先不看答案，也不要把已有 web 应用改个名称就当成完成；要能解释每个字段。

## 1. 任务卡

先在 Mac 终端执行 `export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"`，确认 `kubectl get nodes` 显示三台 UTM 节点 Ready，再创建以下资源。所有新资源都位于 **`cka-w1-check`** 命名空间。

| 项目 | 要求 |
| --- | --- |
| Deployment | 名称 `review-web`，2 个副本 |
| 容器 | 名称 `nginx`，镜像 `nginx:1.30.5-alpine`，容器端口 80 |
| Pod 标签 | `app: review-web` |
| Service | 名称 `review-web`，类型 ClusterIP |
| Service 端口 | `port: 8080`，`targetPort: 80` |
| 测试 Pod | 名称 `review-client`，镜像 `busybox:1.37.0`，保持运行以供 exec |
| 配置保存 | 自己的 YAML 放进 `week-01/practice/` |

此外完成：

1. 从 `review-client` 访问 `http://review-web:8080`，看到 Nginx 页面。
2. 将 Deployment 扩容至 3 个副本，验证后恢复 2 个，并使自己的 YAML 最终也保存 2。
3. 删除一个应用 Pod，观察出现新的 Pod，最后仍有 2 个副本。
4. 在 Mac 使用本地 **8082** 端口访问应用。
5. 查看应用日志，并指出你用哪个 context、哪个命名空间完成了任务。
6. 用 `kubectl get pods -n cka-w1-check -o wide` 记录应用 Pod 实际所在的节点，解释为什么两个副本不保证分布到不同 VM。

如果 `cka-w1-check` 已存在，先判断是不是之前的本课验收资源；重做可以复用，不要覆盖无关内容。

## 2. 分层提示：卡住时逐层看

**提示一：** 需要 Namespace、Deployment、Service 和一个客户端 Pod。资源创建顺序要考虑命名空间先存在。

**提示二：** Service 的 selector 应匹配 Pod 模板上的标签。题目有三个端口：容器 80、Service 8080、Mac 8082。

**提示三：** 可以用 `kubectl create deployment ... --dry-run=client -o yaml` 起草，再补充配置。测试 Pod 可以参考第 4 天的 toolbox 思路。

**提示四：** 本机端口转发需要指定 Service 的端口，而不是机械照抄容器端口。完整操作见 [参考答案](answers.md)。

## 3. 验收清单：共 100 分

这是本教程自测分数，目标是发现缺口，不对应 CKA 的评分规则。

| 验收项 | 分值 |
| --- | --- |
| kubeconfig、context 与 Namespace 正确，资源名称符合要求 | 10 |
| Deployment 镜像、标签正确，2 个副本就绪 | 20 |
| Service 端口、selector 正确，后端存在 | 15 |
| 从客户端 Pod 访问 Service 成功 | 15 |
| 扩缩容和删除 Pod 后补建，最终回到 2 副本 | 15 |
| Mac 本地端口访问成功 | 10 |
| 找到日志，并解释期望状态、标签与端口 | 10 |
| 配置文件可重复使用、错题记录完整 | 5 |

80 分以上且「内部访问、自动补建、context/Namespace」三项都通过，可以进入第二周。未达标时，只重练失败的部分，不必从头重装集群。

## 4. 十个口头问题

1. Mac、UTM、K3s、kubectl 分别负责什么？
2. 一个 Pod 能不能有多个容器？
3. 为什么删除 Deployment 管理的 Pod 后会出现新 Pod？
4. 三个副本是否一定分布在三台机器？
5. Service 根据什么选择 Pod？
6. `port`、`targetPort`、`containerPort` 分别表示什么？
7. 为什么 Mac 通常不能直接访问 ClusterIP？
8. Pod 显示 Running 能证明 HTTP 一定正常吗？
9. `ImagePullBackOff` 时为什么应先看事件？
10. 同名 `web` 出现在不同 Namespace 中，是否是同一个对象？

能用两三句话讲清即可，答案在 [参考答案](answers.md)。

## 5. 整理与清理

先记录自己的结果。可以保留实验资源，第二周继续使用。

如果明确要清理本周练习，下面的命令会删除两个命名空间及其中全部资源；只在确认它们仅含本周练习后执行：

```bash
kubectl --kubeconfig "$HOME/.kube/k3s-utm.yaml" get deployments,pods,services -n cka-w1
kubectl --kubeconfig "$HOME/.kube/k3s-utm.yaml" get deployments,pods,services -n cka-w1-check
kubectl --kubeconfig "$HOME/.kube/k3s-utm.yaml" delete namespace cka-w1 cka-w1-check
```

不需要卸载 K3s：现有集群中还有其他应用。命名空间清理后，保存在 Mac 上的教程和 YAML 仍在，可以按顺序重新创建。

最后写下第二周最值得继续解决的一个问题，例如：「Ready 状态和应用健康有什么区别？」这正好会连接到下一周的探针学习。
