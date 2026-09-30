# 第 6 天：从现象找到原因

[上一课](05-review.md) · [目录](README.md) · [下一课](07-assessment.md)

**用时：180 分钟。** 建议安排：准备与方法 20 分钟、实验一 35 分钟、休息 10 分钟、实验二 35 分钟、实验三 30 分钟、重建与复盘 50 分钟。

每次只制造一个故障，修好并验证后，再进入下一个实验。所有操作限定在 `cka-w1`。

## 1. 建立正常基线

```bash
# 先在终端进入本仓库根目录
export KUBECONFIG="$HOME/.kube/k3s-utm.yaml"
kubectl config current-context
kubectl apply -f week-01/manifests/namespace.yaml
kubectl apply -f week-01/manifests/web-deployment.yaml
kubectl apply -f week-01/manifests/web-service.yaml
kubectl apply -f week-01/manifests/toolbox-pod.yaml
kubectl rollout status deployment/web -n cka-w1 --timeout=180s
kubectl wait -n cka-w1 --for=condition=Ready pod/toolbox --timeout=180s
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

先确认访问正常。否则后面无法分辨哪个问题是故障实验造成的。

## 2. 使用一条固定的排查顺序

```text
确认 kubeconfig / API 地址 / namespace
       ↓
get：看范围与状态
       ↓
describe / events：看调度、启动等事件
       ↓
logs：看运行过的应用说了什么
       ↓
核对配置，提出一个原因假设
       ↓
只修改相关字段，再重复原来的验证
```

有些故障中容器根本没启动，日志就没有帮助；应先看事件。也不需要每次机械执行全部命令，重点是用证据缩小范围。

## 3. 实验一：镜像名称有误

用一个专门的 Deployment 制造故障，保留原来的 web 服务正常运行：

```bash
kubectl create deployment broken-image -n cka-w1 --image=nginx:cka-week1-no-such-tag
kubectl get pods -n cka-w1 -l app=broken-image -w
```

等看到 `ErrImagePull` 或 `ImagePullBackOff` 后按 `Ctrl+C`。若暂时是 `ContainerCreating`，继续观察一会儿。

执行：

```bash
kubectl describe pods -n cka-w1 -l app=broken-image
kubectl get events -n cka-w1 --sort-by=.metadata.creationTimestamp
kubectl get deployment broken-image -n cka-w1 -o yaml
```

先记下三件事，再看修复方法：

1. 实际正在拉取哪个镜像？
2. Events 中的完整错误是什么？
3. 容器有没有真正启动？

这个实验故意使用不存在的标签。**但现实中的 ImagePullBackOff 不只表示标签错误**，还可能是网络超时、认证、访问频率限制或架构不匹配。若你看到的是网络错误，应先解决它，不能仅凭状态名称断言根因。

修复镜像：

```bash
kubectl set image deployment/broken-image -n cka-w1 nginx=nginx:1.30.5-alpine
kubectl rollout status deployment/broken-image -n cka-w1 --timeout=180s
kubectl get pods -n cka-w1 -l app=broken-image
```

`nginx=...` 的左边是容器名称，右边是镜像。可在 Deployment 的 `spec.template.spec.containers` 中核对容器名。

最终应有一个 `1/1 Running` 的 Pod。旧的失败 Pod 在滚动替换后消失是正常的。

记录证据后清理这个实验：

```bash
kubectl delete deployment broken-image -n cka-w1
```

## 4. 实验二：Service 没选中任何 Pod

改变 Service 的一个字段：

```bash
kubectl patch service web -n cka-w1 --type=merge -p '{"spec":{"selector":{"app":"wrong"}}}'
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

第二条在变更生效后预期失败。EndpointSlice 和节点上的转发规则会异步更新，刚修改后立即请求仍可能成功；稍等数秒再执行这条请求，并结合下面的后端检查判断结果。`patch` 表示局部修改，此处将 selector 的 `app` 改成 `wrong`。暂时不用背 JSON 写法，重点观察因果关系。

收集证据：

```bash
kubectl get pods -n cka-w1 -l app=web --show-labels
kubectl describe service web -n cka-w1
kubectl get endpointslices -n cka-w1 -l kubernetes.io/service-name=web -o yaml
```

你应该看到应用 Pod 仍在运行，但 Service selector 为 `app=wrong`，对应的 EndpointSlice 没有可用后端地址，或列表中暂时没有对应切片。控制器更新有短暂延迟，可稍后再查。

修复并重新验证：

```bash
kubectl apply -f week-01/manifests/web-service.yaml
kubectl get endpointslices -n cka-w1 -l kubernetes.io/service-name=web
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

若控制器尚未更新完成，稍等数秒再查。必须确认请求恢复成功，才算修复完成。

## 5. 实验三：Pod 存在，但后端端口错了

这次标签保持正确，只把 Service 的目标端口改为 81：

```bash
kubectl patch service web -n cka-w1 --type=json -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":81}]'
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

变更生效后访问预期失败；如果刚修改时仍然成功，等数秒再试，并检查下面的 EndpointSlice 端口是否已更新。`/spec/ports/0/targetPort` 表示修改 `ports` 列表第一个元素的 `targetPort`，客户端仍然访问 Service 的 80 端口。

比较这个实验与上一个实验：

```bash
kubectl get pods -n cka-w1 -l app=web
kubectl describe service web -n cka-w1
kubectl get endpointslices -n cka-w1 -l kubernetes.io/service-name=web -o yaml
kubectl exec -n cka-w1 deployment/web -- nginx -T
```

这次有匹配的 Pod 地址，但后端端口被设为了 81；Nginx 默认配置监听 80。`nginx -T` 会输出配置，找到其中的 `listen` 行。

恢复：

```bash
kubectl apply -f week-01/manifests/web-service.yaml
kubectl exec -n cka-w1 toolbox -- wget -qO- -T 5 http://web:80
```

恢复也需要等待配置传播；若第一次请求仍失败，稍等数秒重试，直到返回欢迎页面。不要通过修改 `containerPort` 来修复：它是端口声明，不会改变 Nginx 实际监听端口。这里应该把 Service 指向正确的应用端口。

## 6. 不看步骤，重新交付一次应用

先结束自己开的 `port-forward`。删除并恢复本课的 web Deployment 和 Service：

```bash
kubectl delete deployment web -n cka-w1
kubectl delete service web -n cka-w1
```

保留 Namespace 和 toolbox。现在合上本页，仅凭目标完成：

1. 用 YAML 恢复两个 Nginx 副本。
2. 恢复 Service，找到对应的 EndpointSlice。
3. 从 toolbox 发出 HTTP 请求并成功。
4. 从 Mac 经本地 8080 端口访问成功。
5. 找到一次访问对应的容器日志。

遇到卡点时可以查 [命令速查](cheatsheet.md)，完成后再对照 [参考答案](answers.md)。

## 7. 本日交付

在 [学习记录](progress.md) 中完成三份短记录，每份都包含：

> 现象 → 检查命令 → 关键证据 → 原因 → 修复 → 验证结果

「访问失败，所以重启了所有 Pod」不是完整的排障记录。你要能指出是哪个字段导致了哪种行为。

资料：[排查 Pod](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/) · [排查 Service](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
