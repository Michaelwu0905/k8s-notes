# 官方资料与教程验证

[目录](README.md)

资料核对日期：2026-09-30。以下链接按正在做的实验选择阅读，不需要第一周全部通读。

## 环境与工具

- [本仓库的 UTM K3s 环境说明](../k3s-utm/README.md)：三台 VM、SSH 别名、kubeconfig 与跨节点实验。
- [K3s 架构](https://docs.k3s.io/architecture)：Server / Agent 的职责，以及单 Server 架构。
- [K3s 数据存储](https://docs.k3s.io/datastore)：单 Server 默认 SQLite。
- [K3s 网络服务](https://docs.k3s.io/networking/networking-services)：CoreDNS、Traefik、ServiceLB 等内置服务。
- [配置 kubectl 访问多个集群](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)：`KUBECONFIG`、`--kubeconfig` 与 context。
- [kubectl 版本偏差规则](https://kubernetes.io/releases/version-skew-policy/)：客户端与 API Server 的支持范围。

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

## 镜像与版本

本教程选用固定标签的 Nginx Alpine 镜像与 BusyBox。镜像标签仍不等于内容摘要。三台 VM 为 Linux ARM64，若替换镜像，应检查其架构支持。

- Nginx：`nginx:1.30.5-alpine`。[官方镜像清单](https://github.com/docker-library/official-images/blob/master/library/nginx)
- BusyBox：`busybox:1.37.0`。[官方镜像清单](https://github.com/docker-library/official-images/blob/master/library/busybox)
- 安装时 K3s 版本为 `v1.36.4+k3s1`；实际学习时以 `kubectl get nodes` 和 `kubectl version` 为准。

## 验证范围

本周 YAML 原先在 Minikube 环境做过实操测试。改为 UTM K3s 后，配置文件保持不变；教程连接方式、节点示例和排障步骤已针对当前集群改写。2026-09-30 只读检查确认三台节点均为 Ready、系统 Pod 正常；使用 `kubectl create --dry-run=client` 验证 8 个资源文档，没有创建练习资源。14 个 Markdown 文件的 70 个本地链接、72 个 shell 代码块的 zsh 语法，以及 YAML 解析均通过检查。当前环境中已有 [跨节点 Service 与 DNS 实验](../k3s-utm/README.md)，但本周所有故障实验尚未在 K3s 上重做。

示例输出用于解释，Pod 名称、IP、节点、时间和事件文字会随实际运行而变化。练习题、时间预算与自测分数是教学设计，不是官方考试标准。
