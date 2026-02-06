# Kubeflow Fleet Bundles

Turnkey Kubeflow for single-node k3s using Rancher Fleet. Includes Istio, TLS, and Dex auth. Longhorn storage is optional.

**Manifests are rebased to Kubeflow v1.11.0 (kubeflow/manifests tag v1.11.0).**

## Quick Start

1. Push this repo to your Git server and update `gitrepo.yaml`:
   - Set `spec.repo` and `spec.branch`.

2. Label your cluster:
   ```bash
   kubectl label cluster <cluster-name> kubeflow=enabled
   ```

3. (Optional) Enable Longhorn storage:
   ```bash
   kubectl label cluster <cluster-name> kubeflow-longhorn=enabled
   ```

4. Register with Fleet:
   ```bash
   kubectl --kubeconfig ~/.kube/rancher-mgmt.yaml apply -f gitrepo.yaml
   ```
   > If you use the Rancher UI, create the GitRepo there (management cluster). The GitRepo CRD is **not** present in downstream clusters.

Fleet will deploy everything in dependency order.

## What Gets Deployed

### Infrastructure

| Bundle | Description |
|--------|-------------|
| `cert-manager` | Self-signed CA + wildcard TLS for `kf.demo` / `*.kf.demo` |
| `istio-system` | Istio base CRDs |
| `istiod` | Istio control plane |
| `istio-gateway` | Istio ingress gateway (NodePort 30080/30443) |

### Kubeflow Components

| Bundle | Description |
|--------|-------------|
| `kubeflow-base` | Namespaces, RBAC, Istio gateway config |
| `kubeflow-admission-webhook` | PodDefaults admission webhook |
| `kubeflow-dex` | Dex OIDC provider (default static demo user) |
| `kubeflow-oauth2-proxy` | oauth2-proxy + Istio external auth policies |
| `kubeflow-prometheus-stack` | Prometheus + Grafana for metrics |
| `kubeflow-profiles` | Profiles + KFAM (multi-user) |
| `kubeflow-user-namespace` | Default Profile + user namespace |
| `kubeflow-central-dashboard` | Central Dashboard UI |
| `kubeflow-pipelines` | ML Pipelines + SeaweedFS (S3-compatible) |
| `kubeflow-notebooks` | Jupyter Notebooks |
| `kubeflow-spark-operator` | Spark Operator (SparkApplication CRDs + controller) |
| `kubeflow-tensorboards` | Tensorboards UI + controller |
| `kubeflow-katib` | Hyperparameter tuning |
| `kubeflow-training-operator` | TFJob, PyTorchJob, MPIJob, etc. |
| `kubeflow-knative` | Knative Serving (required by KServe) |
| `kubeflow-serving` | KServe for model inference |

### Namespaces (reinstall-safe)

`kubeflow-namespace` owns the required namespaces. Delete the GitRepo to remove them cleanly; re‑install will recreate them.

## Deployment Order (handled automatically)

```
cert-manager
istio-system -> istiod -> istio-gateway
kubeflow-base
kubeflow-dex -> kubeflow-oauth2-proxy
kubeflow-prometheus-stack
kubeflow-admission-webhook
kubeflow-profiles -> kubeflow-user-namespace
kubeflow-central-dashboard
kubeflow-pipelines
kubeflow-notebooks
kubeflow-spark-operator
kubeflow-tensorboards
kubeflow-katib
kubeflow-training-operator
kubeflow-knative -> kubeflow-serving
```

## Requirements

- k3s cluster (single node is fine)
- Rancher Fleet installed
- ~8GB RAM minimum (16GB recommended)
- ~50GB disk space

## Accessing Kubeflow

Add a hosts entry so `kf.demo` resolves to your node:

```bash
# local laptop
echo "127.0.0.1 kf.demo" | sudo tee -a /etc/hosts
```

Use HTTPS (required for auth cookies):

```text
https://kf.demo:30443
```

You will see a browser warning because the cert is self-signed. Accept it or install the CA from the `kubeflow-ca` ConfigMap.

Optional port-forward:

```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443
```

Then open `https://kf.demo:8443`.

## Authentication

This bundle uses Dex + oauth2-proxy (Kubeflow default).

**Default demo login:**
- User: `user@example.com`
- Password: `12341234`

If you change the demo user, also update the Profile owner in:
- `kubeflow-user-namespace/user-namespace.yaml`

You can later connect Dex to a real IdP (OIDC/LDAP/etc) without changing the rest of the stack.

## Metrics (Prometheus + Grafana)

Grafana is available at:

```text
https://kf.demo:30443/grafana/
```

Default Grafana credentials:
- User: `admin`
- Password: `admin`

Prometheus UI is available at:

```text
https://kf.demo:30443/prometheus/
```

The Central Dashboard may log `/api/metrics` errors in the browser console. This endpoint is not the Prometheus API and is safe to ignore.

## Storage

Kubeflow Pipelines uses **SeaweedFS** (S3-compatible) for artifact storage in v1.11.0. Longhorn is optional; label the cluster to enable it:
```bash
kubectl label cluster <cluster-name> kubeflow-longhorn=enabled
```

## Customization

### Change storage sizes

Edit PVCs in:
- `kubeflow-pipelines/upstream.yaml` (SeaweedFS PVC)
- `kubeflow-katib/upstream.yaml` (Katib DB PVC, if enabled)

### Change SeaweedFS S3 credentials

Edit the `mlpipeline-minio-artifact` Secret in `kubeflow-pipelines/upstream.yaml`.

### Add more notebook images

Edit the `spawner_ui_config.yaml` ConfigMap in `kubeflow-notebooks/jupyter-web-app.yaml`.
This repo already adds a demo image option:
- `kf-registry.local:5000/kubeflow/kf-notebook-demos:v0.1.0`
- Build assets live in `samples/kubeflow-notebooks/image/`

### Configure external ingress

Edit the `inferenceservice-config` ConfigMap in `kubeflow-serving/kserve.yaml`:
```yaml
"ingressDomain": "kubeflow.your-domain.com",
"urlScheme": "https"
```

## Troubleshooting

### Check bundle status
```bash
kubectl get bundles -n fleet-default
```

### Reinstall issues (namespaces already exist)
If namespaces pre‑exist, delete the GitRepo and wait for namespace cleanup before re‑installing.

### Check component health
```bash
kubectl get pods -n kubeflow
kubectl get pods -n istio-system
```

### Auth issues
- CSRF errors usually mean you are using HTTP. Use HTTPS and clear cookies.

### TLS issues
- Ensure `kubeflow-tls` exists in both `kubeflow` and `istio-system` namespaces.

## Uninstalling

Use the uninstall helper (recommended):
```bash
scripts/uninstall.sh --gitrepo kubeflow --purge-namespaces
```

If you want to remove shared namespaces too (Istio, cert-manager, monitoring):
```bash
scripts/uninstall.sh --gitrepo kubeflow --purge-namespaces --purge-shared
```

If you also want to delete PVCs:
```bash
scripts/uninstall.sh --gitrepo kubeflow --purge-namespaces --delete-pvcs
```

Manual GitRepo removal (management cluster):
```bash
kubectl --kubeconfig ~/.kube/rancher-mgmt.yaml delete gitrepo kubeflow -n fleet-default
```
