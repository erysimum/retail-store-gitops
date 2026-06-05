# Retail Store Platform — GitOps

This is the repo ArgoCD actually watches. It holds the Helm chart that deploys the five services, the ArgoCD config that wires everything together, and the observability layer: SLOs, dashboards, alert routing, and the Istio fault-injection files used for chaos testing.

One of four repos. The cluster itself is built by **[retail-store-infra](https://github.com/erysimum/retail-store-infra)** — start there for the overview.

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
├── platform-app-dev.yaml     # Application → watches the platform repo (Kustomize)
└── apps-appset-dev.yaml      # ApplicationSet → generates the 5 service apps (Helm)

observability/
├── slos/                     # SLO definitions (Pyrra turns these into alerts)
├── dashboards/               # Grafana dashboards as ConfigMaps
├── alertmanager/             # routing config
└── runbooks/                 # what to do when an alert fires

chaos-engineering/                     # Istio fault-injection VirtualServices
```

---

## The one chart for everything

There's a single Helm chart for all five services instead of five separate charts. Each service just brings its own `dev-values.yaml` to switch on the bits it needs. UI turns on the ingress; catalog, cart, checkout, and orders each turn on a database companion. 
---

## How ArgoCD uses it

Two files bootstrap the whole thing, applied once by hand:

```bash
kubectl apply -f argocd/platform-app-dev.yaml
kubectl apply -f argocd/apps-appset-dev.yaml
```

- `platform-app-dev.yaml` points ArgoCD at the **[retail-store-platform](https://github.com/erysimum/retail-store-platform)** repo and applies the cluster policies first (sync-wave 0).
- `apps-appset-dev.yaml` is an ApplicationSet that fans out into five Applications (`ui-dev`, `catalog-dev`, …), each rendering the shared chart with that service's values. These come up after the platform layer (sync-wave 1).

From then on it's pure GitOps: edit a file, open a PR, merge, and ArgoCD reconciles. Self-heal is on, so manual `kubectl` edits get reverted.

---

## Observability and chaos

**SLOs.** Five availability SLOs (one per service plus a system-level one), all on a 1-day window so burn rate shows up within minutes during a demo. Pyrra reads these and generates the Prometheus recording and alert rules using Google's multi-window burn-rate method.

**Dashboards as code.** Grafana dashboards are stored as ConfigMaps with the `grafana_dashboard` label, so Grafana's sidecar auto-imports them on every cluster spin-up. No manual re-import. The RED dashboard is a single parameterized dashboard with a `$service` dropdown that covers all five services.

**Alert routing.** Warnings go to Slack only. Criticals go to Slack and PagerDuty with a paging tag. 

**Fault injection.** The `chaos-engineering/` folder has two Istio VirtualServices for chaos testing without touching any code: a warning tier (0.5% of UI→catalog requests aborted, slow burn, Slack only) and a critical tier (3% aborted, fast burn, Slack + PagerDuty). They share a name so only one can be active at a time — apply one, watch the alert, delete it, apply the other.

---

## License

MIT
