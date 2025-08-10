Environment: 
 - Ubuntu 20.04(aliyun vm) 
 - k8s 1.24 
 - containerd
 - calico

1. Prepare 2 or more vm, 1 master, 1 node
 - Minimum VM configuration: 2 CPU & 2 RAM

2. Run the following command using root user on both master and node:
 - check ufw status, if active, then run 'ufw disable' to disable it
 - Turn off the swap partition: 
   - swapoff -a
   - sed -ri 's/.*swap.*/#&/' /etc/fstab (permanently disable)
 - Set the hostname:
   cat >> /etc/hosts <<EOF
   192.168.11.14 master
   192.168.11.15 node1
   EOF
 - Pass the bridged IPv4 traffic to the iptables chain:
   - touch /etc/sysctl.d/k8s.conf
   - cat >> /etc/sysctl.d/k8s.conf <<EOF
     net.bridge.bridge-nf-call-ip6tables=1
     net.bridge.bridge-nf-call-iptables=1
     net.ipv4.ip_forward=1
     vm.swappiness=0
     EOF
   - sysctl --system
 - Set the ssh key
   - ssh-keygen -t rsa
   - ssh-copy-id -i /root/.ssh/id_rsa.pub root@192.168.11.xx
   - ssh node1 to test if the ssh has been setup successfully
 - Install containerd
   - apt update
   - apt install -y containerd
   - systemctl enable --now containerd
   - run 'systemctl  status containerd' to check if containerd is running
 - Install CNI plugins
   - wget -c https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
   - mkdir -p /opt/cni/bin
   - tar -xzvf  cni-plugins-linux-amd64-v1.1.1.tgz -C /opt/cni/bin/
 - Config the containerd
   - mkdir -p /etc/containerd
   - tee /etc/containerd/config.toml <<EOF
     version = 2
     [plugins]
       [plugins."io.containerd.grpc.v1.cri"]
         sandbox_image = "registry.k8s.io/pause:3.7"
         [plugins."io.containerd.grpc.v1.cri".cni]
           bin_dir = "/opt/cni/bin"
           conf_dir = "/etc/cni/net.d"
         [plugins."io.containerd.grpc.v1.cri".registry]
           [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
             [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
               endpoint = ["https://docker.1ms.run"]
             [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
               endpoint = ["https://registry.aliyuncs.com/google_containers"]
     EOF
 - Load the containerd kernel module
   - cat <<EOF | tee /etc/modules-load.d/containerd.conf
     overlay
     br_netfilter
     EOF
   - modprobe overlay
   - modprobe br_netfilter
 - Restart containerd
   - systemctl restart containerd
   - systemctl status containerd
3. Install kubeadm, kubelet, kubectl both on master and node
 - Update the repository source
   - apt install apt-transport-https ca-certificates -y
   - apt install vim lsof net-tools zip unzip tree wget curl bash-completion pciutils gcc make lrzsz tcpdump bind9-utils -y
   - echo 'deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main' >> /etc/apt/sources.list
   - curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add
   - apt update
 - Install
   - apt-cache madison  kubeadm
   - apt install -y kubelet=1.24.0-00 kubeadm=1.24.0-00 kubectl=1.24.0-00
   - systemctl enable kubelet
4. Install crictl on master
 - VERSION="v1.28.0"
 - wget -c https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
 - tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
 - crictl version
 - configure crictl for containerd
   tee /etc/crictl.yaml <<EOF
   runtime-endpoint: unix:///run/containerd/containerd.sock
   image-endpoint: unix:///run/containerd/containerd.sock
   timeout: 10
   debug: false
   EOF
5. Init the k8s control panel on master
 - kubeadm init --image-repository registry.aliyuncs.com/google_containers --kubernetes-version v1.24.0 --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16
 - will show the following message if succeed:
   
   Your Kubernetes control-plane has initialized successfully!
   To start using your cluster, you need to run the following as a regular user:
     mkdir -p $HOME/.kube
     sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
     sudo chown $(id -u):$(id -g) $HOME/.kube/config
   Alternatively, if you are the root user, you can run:
     export KUBECONFIG=/etc/kubernetes/admin.conf
   You should now deploy a pod network to the cluster.
   Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
     https://kubernetes.io/docs/concepts/cluster-administration/addons/
   Then you can join any number of worker nodes by running the following on each as root:
   kubeadm join 192.168.11.14:6443 --token nrefdp.2mtcwkkshizkj1qa \
	  --discovery-token-ca-cert-hash sha256:564dbb8ec1993f3e38f3b757c324ad6190950156f30f89f7f7d4b244d2b29ec7
 
 - export KUBECONFIG=/etc/kubernetes/admin.conf(if you run this command, then you will need execute it every time when opening new console)
 
6. Add node to k8s
 - kubeadm join 192.168.11.14:6443 --token nrefdp.2mtcwkkshizkj1qa \
	  --discovery-token-ca-cert-hash sha256:564dbb8ec1993f3e38f3b757c324ad6190950156f30f89f7f7d4b244d2b29ec7
7. Deploy calico on master
 - wget https://docs.projectcalico.org/manifests/calico.yaml
 - vim calico.yaml, uncomment the lines and uodate the value:
   - name: CALICO_IPV4POOL_CIDR
     value: "10.244.0.0/16"
 - kubectl apply -f calico.yaml
8. Check if pod and node works
 - kubectl get pods -A, make sure all pod is running
 - kubectl get nodes, all node is running
