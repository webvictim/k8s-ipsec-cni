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

Once the provisioning process is complete, SSH into the Kubernetes master with ```vagrant ssh master```.

We should then be able to see three working nodes:

```
vagrant@kube-master:~$ kubectl get nodes
NAME          STATUS     ROLES     AGE       VERSION
kube-master   NotReady   master    8m        v1.10.0
kube-node1    Ready      <none>    6m        v1.10.0
kube-node2    Ready      <none>    4m        v1.10.0
kube-node3    Ready      <none>    1m        v1.10.0
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
vagrant@kube-master:~$ kubectl get pods -o wide
NAME                                   READY     STATUS    RESTARTS   AGE       IP           NODE
kubernetes-bootcamp-5c69669756-648fc   1/1       Running   0          19m       10.128.3.2   kube-node3
kubernetes-bootcamp-5c69669756-b8ns5   1/1       Running   1          19m       10.128.1.4   kube-node1
kubernetes-bootcamp-5c69669756-crnn2   1/1       Running   0          19m       10.128.3.4   kube-node3
kubernetes-bootcamp-5c69669756-d8b8m   1/1       Running   0          19m       10.128.2.2   kube-node2
kubernetes-bootcamp-5c69669756-sl8xp   1/1       Running   1          19m       10.128.1.3   kube-node1
kubernetes-bootcamp-5c69669756-vg9qf   1/1       Running   1          19m       10.128.1.5   kube-node1
kubernetes-bootcamp-5c69669756-vx6wp   1/1       Running   0          19m       10.128.3.3   kube-node3
kubernetes-bootcamp-5c69669756-xqp25   1/1       Running   0          19m       10.128.2.4   kube-node2
kubernetes-bootcamp-5c69669756-z4x8t   1/1       Running   0          19m       10.128.2.3   kube-node2
```

If we SSH to any of the nodes, we can ping the IP of any pod on any node:

```
$ vagrant ssh kube-node1
vagrant@kube-node1:~$ ping 10.128.3.4
PING 10.128.3.4 (10.128.3.4) 56(84) bytes of data.
64 bytes from 10.128.3.4: icmp_seq=1 ttl=63 time=0.436 ms
```

The kubernetes-bootcamp container listens on port 8080 - we can make HTTP requests to any pod from any node too:

```
vagrant@kube-node2:~$ curl http://10.128.1.3:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-sl8xp | v=1

vagrant@kube-node3:~$ curl http://10.128.2.4:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-xqp25 | v=1
```

We can also set up a nodePort with ```kubectl expose```:

```
vagrant@kube-master:~$ kubectl expose deployment kubernetes-bootcamp --type=NodePort --port 8080
service "kubernetes-bootcamp" exposed
vagrant@kube-master:~$ kubectl describe services kubernetes-bootcamp
Name:                     kubernetes-bootcamp
Namespace:                default
Labels:                   run=kubernetes-bootcamp
Annotations:              <none>
Selector:                 run=kubernetes-bootcamp
Type:                     NodePort
IP:                       10.98.227.224
Port:                     <unset>  8080/TCP
TargetPort:               8080/TCP
NodePort:                 <unset>  30970/TCP
Endpoints:                10.128.1.3:8080,10.128.1.4:8080,10.128.1.5:8080 + 6 more...
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>
```

When we make a curl request to the nodePort, we see the requests getting routed around between the different pods:

```
vagrant@kube-node1:~$ curl http://10.128.1.1:30970
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-crnn2 | v=1
vagrant@kube-node1:~$ curl http://10.128.1.1:30970
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-648fc | v=1
vagrant@kube-node1:~$ curl http://10.128.1.1:30970
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-z4x8t | v=1
vagrant@kube-node1:~$ curl http://10.128.1.1:30970
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5c69669756-crnn2 | v=1
```

The nodes can be freely rebooted and their IPSEC connections will be re-established when the node comes back up, giving us a full mesh setup. The same is true if we restart the ipsec daemons or run "ipsec down mesh-left" or similar - strongSwan is set up to always re-establish the tunnels.

strongSwan's documentation also states that the kernel route traps on the incoming/outgoing traffic should prevent any unencrypted traffic from flowing.


### Notes and observations

* IP exhaustion
    * Using the IPAM host-local plugin with the standard data directory (/var/lib/cni) means that eventually the pool of host-local IPs will be depleted as it's never cleaned up. We solve this by overriding the 'dataDir' properly in the host-local section and using a directory under /run instead (which will be cleared whenever the node is rebooted)

* strongSwan auto=start vs auto=route
    * Setting auto=start in the ipsec.conf file will automatically start an IPSEC tunnel when strongSwan starts, but it doesn't provide any guarantee that the tunnel will always be re-established - this is why we use auto=route instead, which causes the kernel to trap the traffic and bring the tunnels up on demand.

* Kubelet/strongSwan start order
    * When Kubelet starts, it doesn't bring up the cni0 bridge until a pod is started that needs to use CNI. This means that strongSwan won't work until it's restarted after the first pod is created. This is quite messy, so we get around this by creating the cni0 bridge ourselves and assigning the correct IP address to it before Kubelet or strongSwan are started. We also add a systemd drop-in override file to specify that strongSwan should always be started after kubelet.service for tidiness.
    * It appears that the reason for strongSwan not working correctly is that its kernel route traps on the IPSEC tunnels don't work when a new interface is added which happens to be part of the leftsubnet or rightsubnet - exactly what happens with our CNI setup.

* iptables/traffic forwarding issues
    * By default, the policy on the FORWARD chain is DROP which stops us from communicating from pod to pod across the IPSEC tunnel.
    * We add a startup script to bring the cni0 bridge back up correctly on restart and also to re-add the firewall rules to the FORWARD chain which allow traffic to flow in/out of cni0 over the IPSEC tunnels. We could probably accomplish something similar with iptables-persistent but Kubernetes and Docker both like to have control of iptables rules so it seems easier just to re-add the rules ourselves and let them keep control of the bigger picture.
