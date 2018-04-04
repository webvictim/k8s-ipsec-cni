# k8s-ipsec-cni

Sample implementation of a 3-node Kubernetes cluster using strongSwan and a host-local CNI plugin to provide IPSEC-based networking for pods.

The CNI plugin configuration is mostly taken from the [CNI plugin reference](https://github.com/containernetworking/cni/blob/master/SPEC.md
).

Requirements:
* Working installation of Hashicorp Vagrant 2 (https://www.vagrantup.com/) with either of these provisioners:
    * virtualbox
    * libvirt

### Deployment

1. Check out this repo into a directory: ```git clone https://github.com/webvictim/k8s-ipsec-cni```

2. cd into the directory: ```cd k8s-ipsec-cni```

3. Run ```vagrant up --provision```

The initial startup/provisioning process takes around 10-15 minutes depending on the speed of the test machine and the internet connection.

Once the provisioning process is complete, SSH into the Kubernetes master with ```vagrant ssh kube-node1```.

We should then be able to see three working nodes:

```
vagrant@kube-node1:~$ kubectl get nodes
NAME         STATUS    ROLES     AGE       VERSION
kube-node1   Ready     master    14m       v1.10.0
kube-node2   Ready     <none>    11m       v1.10.0
kube-node3   Ready     <none>    9m        v1.10.0
```

To test, we'll run 9 replicas of the kubernetes-bootcamp image as found [here](https://console.cloud.google.com/gcr/images/google-samples/GLOBAL) - this will distribute 3 pods per node:

```
kubectl run kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1 --port=8080 --replicas 9
```

Then view the status of the deployment:

```
vagrant@kube-master:~$ kubectl get deployments
NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   9         9         9            9           19m
```

Getting info about the pods will show us the IP address assigned to each pod - these are taken sequentially from the CNI range on each node by the plugin:

```
vagrant@kube-node1:~$ kubectl get pods -o wide
NAME                                   READY     STATUS    RESTARTS   AGE       IP           NODE
kubernetes-bootcamp-5c69669756-2kpdw   1/1       Running   0          25s       10.128.2.6   kube-node2
kubernetes-bootcamp-5c69669756-c497b   1/1       Running   0          25s       10.128.3.9   kube-node3
kubernetes-bootcamp-5c69669756-d4fjf   1/1       Running   0          25s       10.128.3.8   kube-node3
kubernetes-bootcamp-5c69669756-dcwhv   1/1       Running   0          25s       10.128.2.7   kube-node2
kubernetes-bootcamp-5c69669756-mb4qt   1/1       Running   0          25s       10.128.1.5   kube-node1
kubernetes-bootcamp-5c69669756-mq7hp   1/1       Running   0          25s       10.128.3.7   kube-node3
kubernetes-bootcamp-5c69669756-pxsmg   1/1       Running   0          25s       10.128.1.3   kube-node1
kubernetes-bootcamp-5c69669756-v6plw   1/1       Running   0          25s       10.128.2.8   kube-node2
kubernetes-bootcamp-5c69669756-x8sc4   1/1       Running   0          25s       10.128.1.4   kube-node1
```

If we SSH to any of the nodes, we can ping the IP of any pod on any node:

```
$ vagrant ssh kube-node1
vagrant@kube-node1:~$ ping 10.128.3.9
PING 10.128.3.9 (10.128.3.9) 56(84) bytes of data.
64 bytes from 10.128.3.9: icmp_seq=1 ttl=63 time=0.950 ms
```

The kubernetes-bootcamp container listens on port 8080 - we can make HTTP requests to any pod from any node too:

```
vagrant@kube-node2:~$ curl http://10.128.1.4:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-x8sc4 | v=1

vagrant@kube-node3:~$ curl http://10.128.2.6:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-2kpdw | v=1
```

We can also set up a nodePort with ```kubectl expose```:

```
vagrant@kube-node1:~$ kubectl expose deployment kubernetes-bootcamp --type=NodePort --port 8080
service "kubernetes-bootcamp" exposed
vagrant@kube-node1:~$ kubectl describe services kubernetes-bootcamp
Name:                     kubernetes-bootcamp
Namespace:                default
Labels:                   run=kubernetes-bootcamp
Annotations:              <none>
Selector:                 run=kubernetes-bootcamp
Type:                     NodePort
IP:                       10.105.161.103
Port:                     <unset>  8080/TCP
TargetPort:               8080/TCP
NodePort:                 <unset>  31990/TCP
Endpoints:                10.128.1.3:8080,10.128.1.4:8080,10.128.1.5:8080 + 6 more...
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>
```

When we make a curl request to the nodePort, we see the requests getting routed around between the different pods:

```
vagrant@kube-node1:~$ curl http://10.128.1.1:31990
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-dcwhv | v=1
vagrant@kube-node1:~$ curl http://10.128.1.1:31990
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-c497b | v=1
vagrant@kube-node1:~$ curl http://10.128.1.1:31990
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-x8sc4 | v=1
vagrant@kube-node1:~$ curl http://10.128.1.1:31990
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-mb4qt | v=1
```

The nodes can be freely rebooted and their IPSEC connections will be re-established when the node comes back up, giving us a full mesh setup. The same is true if we restart the ipsec daemons or run "ipsec down mesh-left" or similar - strongSwan is set up to always re-establish the tunnels.


### Notes and observations

* IP exhaustion
    * Using the IPAM host-local plugin with the standard data directory (/var/lib/cni) means that eventually the pool of host-local IPs will be depleted as it's never cleaned up. We solve this by overriding the 'dataDir' properly in the host-local section and using a directory under /run instead (which will be cleared whenever the node is rebooted)

* Kubelet/strongSwan start order
    * When Kubelet starts, it doesn't bring up the cni0 bridge until a pod is started that needs to use CNI. This means that strongSwan won't work until it's restarted after the first pod is created. This is quite messy, so we get around this by creating the cni0 bridge ourselves and assigning the correct IP address to it before Kubelet or strongSwan are started. We also add a systemd drop-in override file to specify that strongSwan should always be started after kubelet.service for tidiness.

* iptables/traffic forwarding issues
    * By default, the policy on the FORWARD chain is DROP which stops us from communicating from pod to pod across the IPSEC tunnel.
    * We add a startup script to bring the cni0 bridge back up correctly on restart and also to re-add the firewall rules to the FORWARD chain which allow traffic to flow in/out of cni0 over the IPSEC tunnels. We could probably accomplish something similar with iptables-persistent but Kubernetes and Docker both like to have control of iptables rules so it seems easier just to re-add the rules ourselves and let them keep control of the bigger picture.
    * strongSwan appears to have some issues when it's set up to use policy based routing where traffic actually flows in the clear rather than going over the IPSEC tunnels. To combat this, we stopped using policy-based IPSEC and switched to route-based IPSEC instead where we create a tunnel and explicitly tag traffic that is to be sent over it.
