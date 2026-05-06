# Runbook: High Error Rate

## When This Fires

A retail store service is returning HTTP 5xx errors for more than 1% (warning)
or 5% (critical) of requests over the last 5-10 minutes.

The Slack/PagerDuty alert tells you **which service** is affected — check the
`service` field in the alert.

## Severity

- **Critical**: > 5% error rate for 5 minutes — phone wakes you up
- **Warning**: > 1% error rate for 10 minutes — Slack only

## Impact

Depends on the service:
- **UI**: users see "Something went wrong" on the storefront
- **Catalog**: empty product listings, broken product pages
- **Cart**: items can't be added to cart, "Add to cart" fails
- **Orders**: checkout fails at the final step, no orders persist
- **Checkout**: payment flow breaks

**In all cases, revenue is being lost.**

## Investigation Steps

Replace `<service>` with the affected service name from the alert
(e.g., `catalog-dev`, `ui-dev`, `cart-dev`, `orders-dev`).

### Step 1: Confirm the alert in Grafana

Open the **Retail Store — RED Metrics** dashboard. Find the affected service's
"Error Rate" panel. If red and rising, alert is real. If green, false alarm.

### Step 2: Check pod status

```bash
kubectl get pods -n <service>-dev
```

Look for: `CrashLoopBackOff`, `Error`, `OOMKilled`, `0/1 Running`.

### Step 3: Check recent deployments

```bash
kubectl rollout history deployment/<service> -n <service>-dev
```

Was there a deployment in the last hour? **That's almost always the cause.**

### Step 4: Check application logs

```bash
kubectl logs -n <service>-dev -l app=<service> --tail=100
```

Look for stack traces, database connection errors, OOMs, panic messages.

### Step 5: Check downstream dependencies

Each service has a database companion in dev:

```bash
# Catalog → MariaDB
kubectl get pods -n catalog-dev -l app=catalog-db

# Cart → DynamoDB Local
kubectl get pods -n cart-dev -l app=carts-db

# Checkout → Redis
kubectl get pods -n checkout-dev -l app=checkout-redis

# Orders → PostgreSQL
kubectl get pods -n orders-dev -l app=orders-db

# UI has no database — depends on the other 4 services
```

If a database pod is down, the service that depends on it will return 5xx.

## Likely Causes (Ordered By Frequency)

1. **Bad deployment** — new image has a bug. Roll back.
2. **Database down** — companion DB pod crashed.
3. **Connection pool exhausted** — too many concurrent requests.
4. **Memory leak** — pod hits memory limit, gets OOMKilled.
5. **Downstream service failing** (UI only — catalog/cart/etc. is the real issue).

## Resolution Actions

### Roll back a bad deployment

```bash
kubectl rollout undo deployment/<service> -n <service>-dev
kubectl rollout status deployment/<service> -n <service>-dev
```

### Restart a crashed database

```bash
kubectl rollout restart deployment/<db-name> -n <service>-dev
kubectl rollout status deployment/<db-name> -n <service>-dev
```

After DB is back, restart the app so it reconnects:

```bash
kubectl rollout restart deployment/<service> -n <service>-dev
```

### Scale up under load

```bash
kubectl scale deployment/<service> -n <service>-dev --replicas=4
```

This is temporary. Permanent fix: PR a higher `replicas` value in
`helm/apps/<service>/dev-values.yaml`.

### Memory leak / OOMKilled

In emergency, increase memory limit:

```bash
kubectl patch deployment <service> -n <service>-dev \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"<service>","resources":{"limits":{"memory":"1Gi"}}}]}}}}'
```

Then PR the permanent change in `helm/apps/<service>/dev-values.yaml`.

## After Resolution

1. Confirm error rate is back below 1% in Grafana.
2. Acknowledge the alert in PagerDuty.
3. If a deployment was rolled back, file a bug to fix the underlying issue
   before redeploying.
4. Write a post-mortem if downtime exceeded 5 minutes.