# Cluster Autoscaler - IRSA (IAM Roles for Service Accounts)
# This creates an IAM role that the Cluster Autoscaler pod assumes via IRSA

# IAM Role for Cluster Autoscaler (IRSA)
module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-cluster-autoscaler"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  # Use the built-in Cluster Autoscaler policy
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [var.cluster_name]

  tags = {
    Name        = "${var.cluster_name}-cluster-autoscaler"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Kubernetes Service Account and Deployment for Cluster Autoscaler
# Note: These resources require kubectl access after cluster is created
# Run 'kubectl apply' commands manually after terraform apply completes

locals {
  cluster_autoscaler_yaml = <<-YAML
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: cluster-autoscaler
      namespace: kube-system
      labels:
        k8s-addon: cluster-autoscaler.addons.k8s.io
        k8s-app: cluster-autoscaler
      annotations:
        eks.amazonaws.com/role-arn: ${module.cluster_autoscaler_irsa.iam_role_arn}
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: cluster-autoscaler
      labels:
        k8s-addon: cluster-autoscaler.addons.k8s.io
        k8s-app: cluster-autoscaler
    rules:
      - apiGroups: [""]
        resources: ["events", "endpoints"]
        verbs: ["create", "patch"]
      - apiGroups: [""]
        resources: ["pods/eviction"]
        verbs: ["create"]
      - apiGroups: [""]
        resources: ["pods/status"]
        verbs: ["update"]
      - apiGroups: [""]
        resources: ["endpoints"]
        resourceNames: ["cluster-autoscaler"]
        verbs: ["get", "update"]
      - apiGroups: [""]
        resources: ["nodes"]
        verbs: ["watch", "list", "get", "update"]
      - apiGroups: [""]
        resources: ["namespaces", "pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
        verbs: ["watch", "list", "get"]
      - apiGroups: ["batch"]
        resources: ["jobs"]
        verbs: ["watch", "list", "get"]
      - apiGroups: ["extensions", "apps"]
        resources: ["daemonsets", "replicasets", "statefulsets"]
        verbs: ["watch", "list", "get"]
      - apiGroups: ["policy"]
        resources: ["poddisruptionbudgets"]
        verbs: ["watch", "list"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: cluster-autoscaler
      labels:
        k8s-addon: cluster-autoscaler.addons.k8s.io
        k8s-app: cluster-autoscaler
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-autoscaler
    subjects:
      - kind: ServiceAccount
        name: cluster-autoscaler
        namespace: kube-system
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: cluster-autoscaler
      namespace: kube-system
      labels:
        app: cluster-autoscaler
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: cluster-autoscaler
      template:
        metadata:
          labels:
            app: cluster-autoscaler
        spec:
          serviceAccountName: cluster-autoscaler
          containers:
            - name: cluster-autoscaler
              image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.29.0
              resources:
                requests:
                  cpu: 100m
                  memory: 300Mi
                limits:
                  cpu: 100m
                  memory: 300Mi
              command:
                - ./cluster-autoscaler
                - --v=4
                - --stderrthreshold=info
                - --cloud-provider=aws
                - --skip-nodes-with-local-storage=false
                - --expander=least-waste
                - --balance-similar-node-groups
                - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${var.cluster_name}
              volumeMounts:
                - name: ssl-certs
                  mountPath: /etc/ssl/certs/ca-certificates.crt
                  readOnly: true
              imagePullPolicy: "Always"
          volumes:
            - name: ssl-certs
              hostPath:
                path: "/etc/ssl/certs/ca-bundle.crt"
  YAML
}

# Output the IAM role ARN for reference
output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler (use in k8s ServiceAccount annotation)"
  value       = module.cluster_autoscaler_irsa.iam_role_arn
}

# Output the YAML manifest for manual application
output "cluster_autoscaler_manifest" {
  description = "Kubernetes manifest for Cluster Autoscaler (apply with kubectl after cluster is ready)"
  value       = local.cluster_autoscaler_yaml
}