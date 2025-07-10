# EKS + ALB Controller + Test App Deployment

This repository provisions an AWS EKS cluster with:
- VPC & subnets
- EKS + managed node group
- ALB Ingress Controller (with IAM roles/policies)
- Test nginx Deployment, Service, and Ingress
- Application Load Balancer routing to pods

---

## 🚀 Prerequisites

- AWS CLI (`aws configure`)
- Terraform ≥ 1.5
- Helm ≥ 3.x
- kubectl

---

## 📂 Files

| File              | Description                                |
|--------------------|--------------------------------------------|
| `main.tf`          | Terraform EKS + ALB Controller            |
| `outputs.tf`       | Terraform outputs                         |
| `variables.tf`     | Terraform variables                       |
| `iam-policy.json`  | AWS policies needed for ALB/Cluster Autoscaler |
| `hello-app.yaml`   | Test Deployment + Service + Ingress       |

---

### Note

***This deployment requires appropriate values in the variables.tf file to operate correctly***
***The code will need to be run twice to apply the helm charts for alb/Autoscaler***

#### Test APP

### Configure kubectl after deployment:
```bash
aws eks update-kubeconfig --region <region> --name <cluster_name> --profile <profile>
```
### Verify nodes are active:
```bash
kubectl get nodes
```
### Run test app:
```bash
kubectl apply -f hello-app.yaml
```
### Get ingress:
```bash
kubectl get ingress hello-k8s -w
```
### Try the website to verify ALB connectivity:
```bash
http://<ingress>
***Note: it takes around 5 mins for the endpoint to render***
```
### Cleanup:
```bash
kubectl delete -f hello-app.yaml
helm uninstall aws-load-balancer-controller -n kube-system
helm uninstall cluster-autoscaler -n kube-system
terraform destroy
```
