---
name: observability-and-slos
description: Use when adding logging, metrics, tracing, health checks, SLOs, or alerting — or when building a service surface that needs to be operable and debuggable. Keywords — structured logs, OpenTelemetry, correlation id, RED metrics, liveness, readiness, SLI, SLO, error budget, alerting.
---

# Observability and SLOs

## Overview

You cannot operate, debug, or improve what you cannot see. Observability is designed in, not bolted on after the first outage. The first question in every incident is "what changed and who is affected" — a system that can't answer it turns a five-minute fix into an archaeology dig.

## The Principles (universal)

- **The three signals.** Emit **structured logs** (machine-parseable, not free text), **metrics** (counts, rates, durations), and **traces** (a request's path across services). A request carries a **correlation/trace id** end to end.
- **Instrument the golden signals** for every surface: **rate, errors, duration** (RED) per endpoint/operation, plus resource saturation. A new endpoint isn't "done" until it's observable.
- **Health is an endpoint, not a guess.** Expose **liveness** ("am I running?") and **readiness** ("can I serve traffic?") as distinct checks.
- **Define SLOs for critical journeys**, with **SLIs** that measure them and an **error budget** that makes reliability-vs-features an explicit, data-driven trade-off.
- **Alert on symptoms, not causes.** Page when users are hurting (SLO burn, readiness failing), not on every internal blip. Every alert must be **actionable** — an alert nobody acts on trains people to ignore alerts.

## The Mechanisms (this stack)

- **Structured JSON logs to stdout**, collected by the platform (e.g. AKS → Azure Monitor / Log Analytics). No free-text logging in services.
- **OpenTelemetry** in the app server and PostGraphile; export traces/metrics to Azure Monitor / Application Insights (or Prometheus/Grafana).
- **Correlation id propagated across the data path** — generated at the edge, passed Browser → App → PostGraphile alongside context headers, attached to every log line and span.
- **RED metrics** per HTTP route and GraphQL operation; **Postgres slow-query log** + `pg_stat_statements`.
- **Liveness/readiness endpoints** wired to Kubernetes probes (see `cloud-delivery-aks`). Readiness reflects real dependency health (can it reach the DB?), not just process-up.
- **Frontend:** report web-vitals and client errors to the same backend.
- **SLOs per journey** with dashboards and **burn-rate alerts**.

## When to scale this

A pre-launch/local project implements structured logs + health endpoints now and defers SLOs/alerting until there are real users to protect. State the mode in the first decision record.

Full rationale: `docs/engineering-constitution.md` Articles IX & XVI.
