1. 部署nginx和对应的svc后，无法通过node的公网Ip加映射的端口号来访问nginx, 但是集群内部可以访问

 - 修改安全组的入方向规则，增加'目的:1/65535'的端口号允许规则

2. 新创建dashboard token: kubectl -n kubernetes-dashboard create token dashboard-admin
