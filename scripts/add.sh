kubectl --kubeconfig ~/.kube/rancher-mgmt.yaml apply -f - <<'YAML'
  apiVersion: fleet.cattle.io/v1alpha1
  kind: GitRepo
  metadata:
    name: kfdemo
    namespace: fleet-default
  spec:
    repo: https://github.com/stevenbecht/kubeflow-fleet
    branch: master
    paths:
    - cert-manager
    - istio-system
    - istiod
    - istio-gateway
    - kubeflow-namespace
    - kubeflow-base
    - kubeflow-dex
    - kubeflow-oauth2-proxy
    - kubeflow-prometheus-stack
    - kubeflow-crds
    - kubeflow-admission-webhook
    - kubeflow-profiles
    - kubeflow-user-namespace
    - kubeflow-central-dashboard
    - kubeflow-pipelines
    - kubeflow-notebooks
    - kubeflow-tensorboards
    - kubeflow-katib
    - kubeflow-training-operator
    - kubeflow-knative-crds
    - kubeflow-knative
    - kubeflow-serving
    - kubeflow-spark-operator
    targets:
    - name: ds1
      clusterSelector:
        matchLabels:
          management.cattle.io/cluster-display-name: ds1
    pollingInterval: 5m
YAML
