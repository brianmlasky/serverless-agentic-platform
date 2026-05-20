# Serverless Agentic Governance Controller

## Overview
An autonomous, event-driven SRE platform designed to enforce fiscal guardrails on AI-driven Kubernetes workloads. This project demonstrates real-time observability, automated budget remediation, and policy-as-code enforcement on GKE.

## Architecture
![Architecture Diagram](./assets/architecture.png)

Serverless Agentic Governance Controller is an event-driven SRE control plane for AI workloads running on GKE. It ingests telemetry, evaluates policy and budget posture, and enforces guardrails using Kyverno, RBAC, and autonomous remediation logic.

The architecture follows a closed-loop governance model:

1. **AI workloads emit telemetry** including token usage, execution metadata, and namespace context.
2. **The governance controller consumes events** and persists state in Kubernetes ConfigMaps for restart-safe processing.
3. **Policy evaluation determines compliance** against cost thresholds, namespace boundaries, and identity constraints.
4. **Kyverno and RBAC enforce guardrails** at the cluster boundary.
5. **Autonomous remediation executes** when violations persist, including kill-switch and quarantine actions.
6. **Observability pipelines capture every decision** through logs, metrics, alerts, and audit trails.

This design provides deterministic behavior under replay, strong isolation for shared AI workloads, and the operational transparency required for SRE and security review.

## Architecture Principles

- **Event-driven**: reacts to telemetry and policy events in near real time
- **Idempotent**: safe to replay without duplicating enforcement
- **Policy-as-code**: governance is defined declaratively in Kubernetes-native controls
- **Least privilege**: identity and RBAC boundaries restrict blast radius
- **Resilient**: survives controller restarts without losing enforcement context

## Security Posture

The platform applies cloud-native guardrails to AI workload governance:

- **Workload Identity** for secure service-to-service access
- **Namespace segmentation** for workload isolation
- **RBAC enforcement** for scoped remediation permissions
- **Admission control** to block non-compliant workloads before execution
- **Auditability** for traceable governance decisions and remediation actions

## Observability

Every control action is observable and reviewable:

- **Logs** for decision traces and remediation history
- **Metrics** for token usage, policy violations, and budget tracking
- **Alerts** for threshold breaches and enforcement events
- **Audit trails** for compliance and executive reporting


## Key Features
- **Fiscal SecOps:** Real-time token/cost tracking for LLM tool executions.
- **Autonomous Remediation:** Automated kill-switch logic integrated with the Kubernetes API to terminate budget-breaching pods.
- **Policy Compliance:** Built to enforce enterprise security standards using Kyverno (RBAC, namespace labels, and Workload Identity).
- **Resilient Polling:** Decoupled event processing using Kubernetes ConfigMaps, ensuring state-persistence across pod restarts.

## Technology Stack
- **Languages:** Python (AsyncIO, httpx, kubernetes-client)
- **Infrastructure:** Google Kubernetes Engine (GKE), Google Cloud Build
- **Governance:** Kyverno (Policy Engine), RBAC (Role-Based Access Control)
- **Observability:** Structured JSON logging, automated alerting pipeline

## Getting Started
### Prerequisites
- GKE Cluster with Workload Identity enabled.
- Kyverno installed for policy enforcement.

### Deployment
1. **Create Secrets:** `kubectl create secret generic governance-secrets ...`
2. **Apply RBAC:** `kubectl apply -f k8s/litellm/governance-rbac.yaml`
3. **Deploy Controller:** `kubectl apply -f k8s/litellm/governance-controller.yaml`

---
## Connect
**Brian Lasky** | Cloud Architect & SRE
*Specializing in Agentic Infrastructure, Fiscal Governance, and Scalable Cloud Systems.*

- [Website](https://brian-lasky.com)
- [LinkedIn](https://www.linkedin.com/in/brian-lasky-67464086/)
- [GitHub](https://github.com/brianmlasky)

---
## Project Highlights
*Engineered to solve the "Token Runaway" problem in high-scale AI inference environments.*
