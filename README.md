# Kubernetes → CKA 学习手册

为「熟悉 Linux 和 Docker、刚开始学习 Kubernetes」准备的实操教程。学习设备：Apple Silicon MacBook，16GB 内存；每周投入约 8–10 小时。

**从这里开始：[第一周 · 从零部署并理解一个应用](week-01/README.md)。**

教程使用 Markdown，代码块可以复制到终端。建议同时打开教程和两个终端窗口，边读边操作。每课都有目标、解释、实验、预期结果和自测。

## 学习路线

| 阶段 | 重点 | 当前状态 |
| --- | --- | --- |
| 第 1 周 | 建立集群，认识资源，部署、访问、观察与简单排障 | [教程已编写](week-01/README.md) |
| 第 2 周 | 配置、探针、更新回滚、资源与调度 | 待制作 |
| 第 3–4 周 | Service、DNS、Ingress、Gateway API、网络策略 | 待制作 |
| 第 5 周 | 存储、ServiceAccount、RBAC | 待制作 |
| 第 6–7 周 | kubeadm、集群组件、安装、升级与维护 | 待制作 |
| 第 8 周 | 集中排障 | 待制作 |
| 第 9–10 周 | 综合练习、模拟考试与查漏补缺 | 待制作 |
| 第 11–12 周 | 机动时间 | 按实际进度调整 |

## 本周文件

- [第一周目录与时间安排](week-01/README.md)
- [第一天：理解 Kubernetes，检查已有 Minikube](week-01/01-cluster.md)
- [常用命令速查](week-01/cheatsheet.md)
- [环境与操作问题排查](week-01/troubleshooting.md)
- [学习进度与错题记录](week-01/progress.md)
- [三台 Tailscale 主机搭建 K3s 的教程](k3s-tailscale/README.md)
- [已搭建的 UTM 三节点 K3s 练习环境](k3s-utm/README.md)
- [三台 UTM 虚拟机安装 K3s：详细教程](k3s-utm/install-guide.md)

学习时把「看过」和「独立做过」分开记录。遇到不理解的现象，先保留输出，再分析原因。

## 版本与资料

编写日期：2026-09-24。第一周沿用这台 Mac 上现有的 Minikube（Docker 驱动，Kubernetes v1.35.1），实验资源单独放入 `cka-w1` 和 `cka-w1-check` 命名空间。进入备考冲刺阶段，再以 [CKA 官方 FAQ](https://docs.linuxfoundation.org/tc-docs/certification/faq-cka-ckad-cks) 确认考试版本。

本教程的解释和练习为自行编写，官方依据见各课末尾及 [资料索引](week-01/references.md)。
