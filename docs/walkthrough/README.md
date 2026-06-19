# Platform Walkthrough — Chaos Engineering & SLO Observability

A start-to-finish walkthrough of running the retail-store platform under load,
breaking it deliberately, and watching the SLO/alerting pipeline respond.

1. [When traffic first flows (cold start)](01-first-traffic/) — why a fresh cluster
   throws scary alerts that aren't an outage
2. [Load testing with Locust](02-locust/) — real traffic, budgets recover
3. [Diagnosing the load-test failures](03-disable-add-to-cart/) — tracing a 11%
   failure rate to one broken request
4. [Fault injection with Istio](04-fault-injection/) — controlled chaos, real burn
5. [AI SRE agent](05-ai-agent/) — advisory agent investigating a real breach

(See also the [retail-store-ai](https://github.com/erysimum/retail-store-ai) repo.)
