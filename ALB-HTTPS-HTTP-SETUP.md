# Setting Up ALB with HTTP (80) and HTTPS (443)

This guide shows how to configure an ALB to listen on both port 80 (HTTP) and port 443 (HTTPS).

## Prerequisites

1. **ACM Certificate**: You need an SSL/TLS certificate in AWS Certificate Manager (ACM)
2. **ALB Controller**: Already deployed (✅ done in your cluster)
3. **kubectl**: Configured to access your EKS cluster

## Step 1: Create or Get an ACM Certificate

### Option A: Use an existing certificate

List your certificates:
```powershell
aws acm list-certificates --region eu-north-1
```

Copy the certificate ARN (looks like: `arn:aws:acm:eu-north-1:123456789012:certificate/12345678-1234-1234-1234-123456789012`)

### Option B: Create a new certificate

```powershell
# For a domain you own
aws acm request-certificate `
  --domain-name example.com `
  --region eu-north-1 `
  --validation-method DNS

# Then follow DNS validation steps in AWS Console (ACM dashboard)
```

## Step 2: Update the Ingress YAML

Edit [alb-443-80-example.yaml](alb-443-80-example.yaml) and replace:

```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:eu-north-1:YOUR_ACCOUNT_ID:certificate/YOUR_CERT_ID
```

With your actual certificate ARN.

**Example:**
```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:eu-north-1:123456789012:certificate/a1b2c3d4-e5f6-1234-5678-abcdefghijkl
```

## Step 3: Deploy the Ingress (PowerShell)

```powershell
# Deploy the example app and Ingress
kubectl apply -f alb-443-80-example.yaml

# Check the Ingress is created
kubectl get ingress web-app-alb

# Get the ALB DNS name (wait 2-3 minutes for it to appear)
kubectl get ingress web-app-alb -o wide
```

Copy the ADDRESS from the output above.

## Step 4: Test the Ingress

```powershell
# Test HTTP (should redirect to HTTPS or work directly)
curl -v http://<ALB_DNS_NAME>

# Test HTTPS (might show certificate warnings if it's a self-signed cert)
curl -v -k https://<ALB_DNS_NAME>

# Or open in browser
start "https://<ALB_DNS_NAME>"
```

## Configuration Options Explained

### Listen on both ports:
```yaml
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
```
This tells the ALB to accept traffic on ports 80 and 443.

### Certificate ARN:
```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
```
The SSL/TLS certificate to use for HTTPS connections.

### Redirect HTTP to HTTPS (optional):
```yaml
alb.ingress.kubernetes.io/ssl-redirect: '443'
```
When set to '443', all HTTP traffic is redirected to HTTPS.

**Remove or set to 'false'** if you want HTTP traffic to NOT redirect:
```yaml
alb.ingress.kubernetes.io/ssl-redirect: 'false'
```

### SSL Policy (optional):
```yaml
alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
```
Controls which TLS versions are supported. Options:
- `ELBSecurityPolicy-TLS-1-2-2017-01` - Recommended (TLS 1.2+)
- `ELBSecurityPolicy-TLS-1-2-2017-01` - TLS 1.2 only
- `ELBSecurityPolicy-FS-1-2-Res-2019-08` - Forward secrecy enabled

## Troubleshooting

### ALB not showing up
```powershell
# Check Ingress status
kubectl describe ingress web-app-alb

# Check ALB controller logs
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

### Certificate error
- Ensure certificate is in the same region as your cluster (eu-north-1)
- Verify certificate ARN is correct
- Certificate must be validated (not pending)

### HTTPS not working
- Wait 3-5 minutes for ALB to fully deploy
- Check AWS Console > EC2 > Load Balancers > Listeners tab
- Verify certificate is attached to port 443 listener

### Get ALB details in AWS Console
```powershell
# Get ALB name
kubectl get ingress web-app-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Then search for that name in AWS Console > EC2 > Load Balancers
```

## Advanced: Using Multiple Certificates

If you have multiple domains, use hosted zone routing:

```yaml
metadata:
  name: web-app-alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'

spec:
  tls:
  - hosts:
    - example.com
    - www.example.com
    secretName: example-tls  # Not used by ALB, but required by spec
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app
            port:
              number: 80
  - host: www.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app
            port:
              number: 80
```

Then add per-hostname certificate annotations:

```yaml
annotations:
  alb.ingress.kubernetes.io/certificate-arn: |
    arn:aws:acm:eu-north-1:123456789012:certificate/cert-1
  alb.ingress.kubernetes.io/certificate-arn-http-listener: arn:aws:acm:eu-north-1:123456789012:certificate/cert-2
```

## Reference Links

- [AWS Load Balancer Controller Annotations](https://kubernetes-sigs.aws-load-balancer-controller.readthedocs.io/en/latest/guide/ingress/annotations/)
- [AWS Certification Manager](https://aws.amazon.com/certificate-manager/)
- [ALB Ingress Documentation](https://kubernetes-sigs.aws-load-balancer-controller.readthedocs.io/en/latest/guide/ingress/)
