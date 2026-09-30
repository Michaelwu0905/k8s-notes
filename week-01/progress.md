# 第一周学习记录

[目录](README.md) · [验收任务](07-assessment.md)

开始日期：________　计划结束日期：________

## 环境记录

| 项目 | 编写教程时确认的值 | 你开始学习时的值 |
| --- | --- | --- |
| Mac | Apple Silicon，16GB 内存（用户提供） | |
| UTM VM | 3 台 Ubuntu 26.04.1 LTS / ARM64 | |
| K3s Server / Agents | `k3s-master` / `k3s-worker-1`、`k3s-worker-2` | |
| K3s 版本 | `v1.36.4+k3s1`（安装时） | |
| kubeconfig / context | `~/.kube/k3s-utm.yaml` / `default` | |
| Kubernetes Server / kubectl Client | 执行 `kubectl version` 记录 | |

## 进度

「跟做完成」是看着教程成功；「独立完成」是只看目标，可以查文档但不照抄解题步骤。

| 天数 | 计划时间 | 实际时间 | 跟做完成 | 独立完成 | 卡点 |
| --- | --- | --- | --- | --- | --- |
| 1：环境与概念 | 1 小时 | | | | |
| 2：部署与观察 | 1 小时 | | | | |
| 3：YAML | 1 小时 | | | | |
| 4：Service | 1 小时 | | | | |
| 5：休息或补课 | 可选 | | | | |
| 6：排障 | 3 小时 | | | | |
| 7：独立验收 | 2 小时 | | | | |

## 技能清单

- [ ] 检查 UTM VM、K3s 三个节点、kubeconfig 和 API 地址。
- [ ] 能讲清 Cluster、Node、Pod、Deployment、Service、Namespace。
- [ ] 创建 Deployment，并等待应用就绪。
- [ ] 用 get / describe / logs / exec 收集信息。
- [ ] 扩缩容，解释 Pod 被删除后为什么补建。
- [ ] 阅读并修改 Deployment YAML。
- [ ] 解释 Pod labels 与 Service selector 的关系。
- [ ] 从 Mac 和集群内分别验证 HTTP 访问。
- [ ] 找出错误镜像、selector 和 targetPort 三种问题。
- [ ] 完成独立验收，最终配置与运行状态一致。

## 错题记录模板

复制下面的块，为每个问题单独记录。不要只记最终修复命令。

### 问题 1

- 日期与所处章节：
- 我的目标：
- 实际现象、完整报错：
- 当前 kubeconfig / API 地址 / Namespace：
- 我执行的检查命令：
- 最关键的一条证据：
- 根本原因：
- 修复操作：
- 验证方式与结果：
- 隔天重做结果：
- 一周后重做结果：

## 周末复盘

- 自测得分（不是考试预测）：____ / 100
- 我能独立完成的三个操作：
- 我能解释清楚的三个概念：
- 仍然依赖照抄的两项操作：
- 下周开始前要重练的一项：
- 我现在最想理解的一个问题：
