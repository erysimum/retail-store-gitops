# Runbook: Service Down

## When This Fires

Prometheus cannot scrape the affected service's `/metrics` endpoint. The
`up{job="<service>"}` metric has been `0` for 2 minutes.

This means the service is **completely unreachable** — not just slow or erroring.

The Slack/PagerDuty alert tells you which service. Check the `service` field.

## Severity

**Critical** — phone wakes you up immediately.

## Impact

The entire service is unavailable. Depending on which one:
- **UI down** → entire storefront unavailable
- **Catalog down** → no products visible
- **Cart down** → can't add items
- **Orders down** → can't place orders
- **Checkout down** → can't complete purchases

**Revenue is completely halted for that service's functionality.**

## Investigation Steps

Replace `<service>` with the affected service from the alert.

### Step 1: Check pod status

```bash
kubectl get pods -n <service>-dev -l app=<service>
```

**Expected:** at least 1 pod in `Running` state.

**If you see:**
- `CrashLoopBackOff` — app starts then dies. Go to Step 2.
- `ImagePullBackOff` — image doesn't exist in ECR. Check tag in dev-values.yaml.
- `Pending` — no nodes available. Cluster capacity issue.
- `0/1 Running` — pod up but failing readiness probe. Go to Step 3.

### Step 2: If CrashLoopBackOff

```bash
kubectl describe pod -n <service>-dev -l app=<service> | tail -40
kubectl logs -n <service>-dev -l app=<service> --previous --tail=100
```

Common causes:
- Database not reachable
- Bad config (env var missing or wrong)
- Code bug in latest deploy

### Step 3: If readiness probe failing

```bash
# Manually hit the health endpoint from inside the cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://<service>.<service>-dev.svc.cluster.local:8080/<health-path>
```

Health paths by service:
- UI, Cart, Orders → `/actuator/health`
- Catalog → `/health`
- Checkout → `/health`

If 500 → app is up but unhealthy (likely DB issue).
If connection refused → pod isn't actually listening.

### Step 4: Check Prometheus targets

Open Prometheus UI → Status → Targets → search for the service name.
The Error column shows the actual scrape failure reason (timeout, refused, 404).

## Likely Causes

1. **All pods crashed** — rollback latest deployment
2. **Database unreachable** — restart DB pod
3. **NetworkPolicy misconfigured** — recent change blocking traffic
4. **Cluster out of capacity** — pods can't schedule (check node count)

## Resolution Actions

### Roll back recent deployment

```bash
kubectl rollout undo deployment/<service> -n <service>-dev
kubectl rollout status deployment/<service> -n <service>-dev
```

### Restart database

```bash
kubectl rollout restart deployment/<db-name> -n <service>-dev
kubectl rollout status deployment/<db-name> -n <service>-dev
kubectl rollout restart deployment/<service> -n <service>-dev
```

### Force recreate all pods

```bash
kubectl delete pods -n <service>-dev -l app=<service>
```

If new pods also fail, the issue is configuration-level, not pod-level.

### Check cluster capacity

```bash
kubectl get nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

If nodes are at capacity, pods can't schedule. Add a node:
- Edit `terraform.tfvars` → `node_desired_size`
- Or use AWS CLI to scale node group directly (faster):
  ```bash
  aws eks update-nodegroup-config \
    --cluster-name retail-store-dev \
    --nodegroup-name <name> \
    --scaling-config desiredSize=4 \
    --region ap-southeast-2
  ```

## After Resolution

1. Verify pods are `Running` and `Ready`.
2. Test the user-facing functionality (browse store, add to cart, etc.).
3. Acknowledge in PagerDuty.
4. Write post-mortem if downtime exceeded 5 minutes.