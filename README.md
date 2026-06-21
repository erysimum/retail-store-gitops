# Retail Store Platform — GitOps

This is the repo ArgoCD actually watches. It holds the Helm chart that deploys the five services, the ArgoCD config that wires everything together, the observability layer (SLOs, dashboards, alert rules, scrape config, runbooks), and the Istio fault-injection files used for chaos testing.

One of five repos. The cluster itself is built by **[retail-store-infra](https://github.com/erysimum/retail-store-infra)** — start there for the overview.

> 📖 **New here?** The **[Platform Walkthrough](docs/walkthrough/)** is the best place to start — a start-to-finish tour with screenshots: first traffic and SLOs, a Locust load test, tracing a failure to one broken request, Istio fault injection, and the AI SRE agent diagnosing a live breach.

---

## What's in here

```
helm/
├── charts/microservice/      # ONE generic chart for all 5 services
│   ├── Chart.yaml
│   ├── values.yaml           # defaults (database off, ingress off)
│   └── templates/            # deployment, service, serviceaccount, ingress,
│                             #   plus optional database deployment/service
└── apps/
    ├── ui/dev-values.yaml        # ingress on, no database
    ├── catalog/dev-values.yaml   # MariaDB companion
    ├── cart/dev-values.yaml      # DynamoDB Local companion
    ├── checkout/dev-values.yaml  # Redis companion
    └── orders/dev-values.yaml    # PostgreSQL companion

argocd/
├── platform-app-dev.yaml        # Application → platform repo (Kustomize)
├── apps-appset-dev.yaml         # ApplicationSet → the 5 service apps (Helm)
└── observability-app-dev.yaml   # Application → the observability stack

observability/
├── slos-istio/        # SLO definitions (Pyrra turns these into alerts)
├── alerts/            # Prometheus alert rules
├── dashboards/        # Grafana dashboards as ConfigMaps
├── servicemonitors/   # what Prometheus scrapes
├── scrape-configs/    # extra scrape configuration
└── runbooks/          # what to do when an alert fires

chaos-engineering/     # Istio fault-injection VirtualServices
├── catalog-abort-warning.yaml     # 0.5% of requests → HTTP 500 (slow burn)
├── catalog-abort-critical.yaml    # 3% of requests  → HTTP 500 (fast burn)
├── catalog-latency-warning.yaml   # injected delay (slow burn)
└── catalog-latency-critical.yaml  # injected delay (fast burn)

loadtest/
└── locust-deployment.yaml         # Locust load generator
```

---

## The one chart for everything

There's a single Helm chart for all five services instead of five separate charts. Each service just brings its own `dev-values.yaml` to switch on the bits it needs.
---

## How ArgoCD uses it

Three files bootstrap the whole thing, applied once by hand:

```bash
kubectl apply -f argocd/platform-app-dev.yaml
kubectl apply -f argocd/apps-appset-dev.yaml
kubectl apply -f argocd/observability-app-dev.yaml
```

- `platform-app-dev.yaml` points ArgoCD at the **[retail-store-platform](https://github.com/erysimum/retail-store-platform)** repo and applies the cluster policies first (sync-wave 0).
- `apps-appset-dev.yaml` This ApplicationSet automatically creates the five application deployments (ui-dev, catalog-dev, and others), each using the same shared Helm chart with its own configuration. They are deployed after the core platform components are ready.(sync-wave 1).
- `observability-app-dev.yaml` brings up the observability config: SLOs, alert rules, dashboards, and scrape config.

From then on it's pure GitOps: edit a file, open a PR, merge, and ArgoCD reconciles. Self-heal is on, so manual `kubectl` edits get reverted.

---

## Observability

**SLOs.** Availability SLOs (one per service plus a system-level one).

**Dashboards as code.** Grafana dashboards are stored as ConfigMaps with the `grafana_dashboard` label, so Grafana's sidecar auto-imports them on every cluster spin-up.

**Alert routing.** Warnings go to Slack only; criticals go to Slack and PagerDuty with a paging tag. 
---

## Load testing and chaos

**Load.** `loadtest/locust-deployment.yaml` runs Locust in-cluster to generate steady traffic against the UI, so the SLOs and dashboards have something real to measure.

**Fault injection.** The `chaos-engineering/` folder injects failures with Istio, no code changes and no restarts. There are two kinds of fault — aborts (return HTTP 500) and latency (add delay) — each at a warning tier (small, slow burn, Slack only) and a critical tier (larger, fast burn, Slack + PagerDuty). Apply one, watch the alert fire, delete it, try another. 
---

## License

MIT
