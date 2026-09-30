# 官方资料与教程验证

[目录](README.md)

资料核对日期：2026-09-24。以下链接用于查询和延伸阅读，不需要第一周全部通读。按你正在做的实验选择对应页面即可。

## 环境与工具

- [Minikube 入门](https://minikube.sigs.k8s.io/docs/start/)：安装、启动、基本要求。
- [Minikube 状态命令](https://minikube.sigs.k8s.io/docs/commands/status/)：检查 profile 运行状态。
- [Minikube 镜像命令](https://minikube.sigs.k8s.io/docs/commands/image/)：向学习节点加载镜像。
- [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/)：Apple silicon 安装入口。
- [macOS 安装 kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)：安装和客户端/服务端版本要求。

## Kubernetes 核心概念

- [集群组件](https://kubernetes.io/docs/concepts/overview/components/)：第 1 天。
- [Pod](https://kubernetes.io/docs/concepts/workloads/pods/)：第 2 天。
- [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)：第 2–3 天。
- [标签与选择器](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)：第 3–4 天。
- [Namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)：第 3 天。
- [声明式配置](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/)：第 3 天。
- [Service](https://kubernetes.io/docs/concepts/services-networking/service/)：第 4 天。
- [Service 与 Pod 的 DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)：第 4 天。
- [端口转发](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)：第 4 天。
- [排查 Pod](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)：第 6 天。
- [排查 Service](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)：第 6 天。

## 镜像与版本策略

本教程选择小型 Nginx Alpine 镜像和 BusyBox，使用明确的版本标签，避免不同日期拉取 `latest` 带来的行为变化。镜像标签仍不等于内容摘要；本教程的重点是学习资源操作，不是生产镜像供应链设计。

- Nginx：`nginx:1.30.5-alpine`，官方镜像清单包含 ARM64 架构。[镜像清单](https://github.com/docker-library/official-images/blob/master/library/nginx)
- BusyBox：`busybox:1.37.0`，官方镜像清单包含 ARM64 架构。[镜像清单](https://github.com/docker-library/official-images/blob/master/library/busybox)
- 现有 Minikube：Kubernetes v1.35.1；本周不升级或重建已有集群。

## 验证记录

2026-09-28 在现有 Minikube / Kubernetes v1.35.1 上完成核心实操校验。测试使用单独创建的临时命名空间，并将 YAML 中的命名空间替换为该测试空间；现有应用和读者练习空间未用于故障注入。

| 检查项目 | 结果 |
| --- | --- |
| 5 个 YAML 文件，合计 8 个资源文档的解析与基本结构 | 通过 |
| 14 个 Markdown 文件中的 64 个本地链接、代码围栏 | 通过 |
| 77 个 shell 代码块的 zsh 语法检查 | 通过 |
| Deployment 就绪、Service 与 DNS、集群内 HTTP 请求 | 通过 |
| Mac 端口转发访问 | 通过 |
| 扩缩容、删除 Pod 后补建、重新 apply 恢复副本数 | 通过 |
| 错误 selector、错误 targetPort 的故障与恢复 | 通过 |
| 错误镜像标签触发拉取失败，修复镜像后部署成功 | 通过 |
| 周末参考配置：Service 8080 → Pod 80，内部请求及本地转发 | 通过 |
| 临时测试命名空间清理，按测试标签复查无残留 | 通过 |

实测发现 Service 变更与网络转发规则生效之间存在异步延迟，已在第 6 天补充等待、观察和重试说明。实际端口转发测试使用临时空闲本机端口，避免与已有应用冲突；教程选用 8080、8082 作为易记示例，并提供端口冲突处理方法。

这些检查覆盖本机上的核心学习流程，不表示每个可选安装分支或所有网络环境都经过实测。首次安装、下载速度、代理设置仍取决于实际环境。

本课示例输出是为解释而整理的形状，Pod 名称、IP、时间和事件文字可能不同。练习题、时间预算、自测分数是本教程的教学设计，不是官方考试标准。
