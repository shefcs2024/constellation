# Constellation Tenant

Hello and welcome. This repository is how you will deploy and manage your apps within Constellation. Any commits you make will automatically be pushed to Constellation.

## Repository Structure

First of all, it's worth you familiarising yourself with [FluxCD](https://fluxcd.io), because this is the software that reconciles this repository with the cluster.

To tell Flux to reconcile a collection of manifests for you, you need to create a [Kustomization](https://fluxcd.io/flux/components/kustomize/kustomizations) in the `kustomizations/` directory. From here, you can structure the rest of the repository however you want. This template repository contains an example to show you how you could do this.

**NOTE**: thanks to Flux, you do not need to specify `metadata.namespace` on any of the manifests here. Flux will automatically add it on-the-fly to all namespaced resources.

### Updating ConfigMaps & Secrets

One major flaw of Flux is that it does not restart Pods when a commit only changes a [ConfigMap](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/config-map-v1/) or [Secret](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/secret-v1/). To remedy this, [Reloader](https://github.com/stakater/Reloader) is installed on the cluster, and will trigger a restart when a Pod's related [ConfigMaps](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/config-map-v1/) or [Secrets](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/secret-v1/) are modified.

## Constellation's Resources

Constellation has a variety of resources available to tenants. This includes things like storage provisioning, secret encryption, a reverse proxy, etc.

Please contact a Cluster Admin if you need more resources, or would like a service to be provided by the Cluster Admins.

### Storage Classes

There are two types of [Storage Classes](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/storage-class-v1/) available in Constellation:

- `local`: binds to the local storage of the current node, if any is available
- `nfs`: creates an NFS mount so that the storage can be used permanently without binding to a specific node

### Node Labels & Taints

Each node within Constellation has a set of labels and taints that help allocate Pods with specific needs to the correct nodes. Most of these are only useful interally, but a few would be helpful to tenants.

I recommend you only add tolerations or affinity statements when there is a *genuine* need of it. By default, the cluster is set up to automatically assign Pods to the best node available.

#### Labels

- `starsystem.dev/nfs=true`: internal only, node runs the NFS server
- `starsystem.dev/prometheus=true`: internal only, node can run a Prometheus server
- `starsystem.dev/minio=true`: internal only, node runs a MinIO server
- `starsystem.dev/rtc=true`: internal only, node has a Real-Time Clock
- `starsystem.dev/camera=true`: internal only, node has a camera
- `starsystem.dev/games=true`: high compute & memory resources available, intended for game servers only
- `starsystem.dev/database=true`: node can be used to run database servers

#### Taints

Only taints with the effect `PreferNoSchedule` can be tolerated. Any node with a `NoSchedule` or `NoExecute` taint cannot be used by tenants.

- `starsystem.dev/device=true:NoSchedule:NoExecute`: node is a low-power device with very limited resources
- `starsystem.dev/hypervisor=true:NoSchedule:NoExecute`: node is a hypervisor, resources reserved for critical Pods
- `starsystem.dev/wireless-net=true:PreferNoSchedule`: node has a wireless connection rather than wired, not ideal for network-heavy Pods
- `starsystem.dev/nas=true:PreferNoSchedule`: node runs the NAS, resources are reserved
- `starsystem.dev/games=true:PreferNoSchedule`: node's resources are reserved for game servers

### Priority Classes

There are three levels of [Priority Class](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/priority-class-v1/) available to tenants:

- `low`: Has a priority of `10`, and is for pods that should be preempted first if resources are sparse
- `medium`: The default priority for all pods, has a value of `100000`
- `high`: Has a value of `1000000000` and can preempt lower priority pods

Tenants must usually ask for permission to use the `high` Priority Class, and give a justification.

#### Builtin Priorities

Kubernetes has two builtin priority classes: `system-cluster-critical` and `system-node-critical`. Any attempt to use these in a tenant namespace will cause the cluster to reject your pods. These priorities are reserved for cluster-critical infrastructure.

### RBAC

[RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) controls are in place to prevent tenants from viewing/modifying things they really shouldn't be able to. This also means tenants cannot create RBAC manifests, like [Service Accounts](https://kubernetes.io/docs/reference/kubernetes-api/authentication-resources/service-account-v1/), [Roles](https://kubernetes.io/docs/reference/kubernetes-api/authorization-resources/role-v1/) and [Bindings](https://kubernetes.io/docs/reference/kubernetes-api/authorization-resources/role-binding-v1/).

For apps that need a small amount of RBAC access, each tenant's namespace has a [Service Account](https://kubernetes.io/docs/reference/kubernetes-api/authentication-resources/service-account-v1/) called `tenant-service-account` that can be used in any of their apps.

### Sealed Secrets

A shell script (`seal.sh`) is included that will scour the whole repo recurisvely for `.yaml` files whose name starts with `secret`. It then encrypts them using the cluster's public key and stores them next to the original file, with the filename `sealed-<original name>.yaml`.

The decryption keys for [SealedSecrets](https://github.com/bitnami-labs/sealed-secrets) are kept secure on the cluster, to prevent other tenants from decrypting your Secrets. This means that you should make sure to keep a copy of the contents of your Secrets, because you cannot decrypt them once they are encrypted.

### Ingress Controller

A [Traefik](https://traefik.io) server runs on the cluster and will handle all ingress to the cluster. Routes for your Services can be added by using the [IngressRoute](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/#kind-ingressroute) and co manifests.

## Restrictions

Due to the inherent risk, tenant repositories are restricted in what they can do. The primary restrictions in place are:

- You cannot access any of the manifests or volumes in another namespace
- Manifests in this repository will only be pushed to a certain namespace, which can only be changed by a Cluster Admin
- Pods within the namespace are limited to the latest version of the `baseline` [Pod Security Standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/), which means they cannot escalate privileges
- Pods that adhere to the `baseline` PSS rather than `restricted` will be audited
- Pods that follow an outdated version of the `restricted` PSS will receive a warning
- The namespace has a limited CPU and memory budget via a [Resource Quota](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- Permissions to view/modify manifests are heavily restricted, see below
- A [Network Policy](https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/) prevents any egress from your namespace to another tenant's

### Allowed Resources

This is a list of all the Kubernetes resource kinds that can be created, modified, deleted and viewed through this repo. It's easier to tell you what you CAN do, rather than what you can't:

| Manifest type | Permissions |
| --- | --- |
| [ReplicaSet](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/replica-set-v1/) | All |
| [Deployment](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/) | All |
| [DaemonSet](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/daemon-set-v1/) | All |
| [StatefulSet](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/stateful-set-v1/) | All |
| [Pod](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/) | All |
| [Job](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/job-v1/) | All |
| [CronJob](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/cron-job-v1/) | All |
| [ConfigMap](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/config-map-v1/) | All |
| [Secret](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/secret-v1/) | All |
| [SealedSecret](https://github.com/bitnami-labs/sealed-secrets) | All |
| [Service](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/service-v1/) | All |
| [Endpoint](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/endpoints-v1/) | All |
| [EndpointSlice](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/endpoint-slice-v1/) | All |
| [IngressRoute](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/#kind-ingressroute) | All |
| [IngressRouteTCP](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/#kind-ingressroutetcp) | All |
| [IngressRouteUDP](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/#kind-ingressrouteudp) | All |
| [Middleware](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/#kind-middleware) | All |
| [MiddlewareTCP](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/#kind-middlewaretcp) | All |
| [PersistentVolumeClaim](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/persistent-volume-claim-v1/) | All |
| [PersistentVolume](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/persistent-volume-v1/) | All |
| Flux [Kustomization](https://fluxcd.io/flux/components/kustomize/kustomizations) | All |
| Kustomize [Kustomization](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/) | All |

If you attempt to create any other resource, the cluster will give you a 403 error.
