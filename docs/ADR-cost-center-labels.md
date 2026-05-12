# ADR: GCP Cost Center Labels — Per-Component Billing Strategy

**Date:** 2025-05-12  
**Status:** Accepted  
**Decision:** Option B — per-component billing buckets  

## Context

The platform has two distinct cost drivers running in the same GKE cluster:
1. **AI inference** — LiteLLM Gateway proxying Bedrock/Claude API calls
2. **API compute** — FastAPI agentic service handling agent orchestration

## Decision

Use separate `cost-center` labels per component to enable granular GCP billing attribution:

| Namespace | Workload         | `cost-center`   | Rationale                            |
|-----------|-----------------|-----------------|--------------------------------------|
| `litellm` | litellm-gateway | `research-dev`  | AI model inference costs             |
| `agentic` | api-gateway     | `agent-logic`   | API hosting / agent orchestration    |

## Additional Labels (api-gateway, added 2025-05-12)

```yaml
labels:
  app: api-gateway
  version: v2.0.4
  cost-center: agent-logic
  environment: dev
  app.kubernetes.io/name: api-gateway
  app.kubernetes.io/version: v2.0.4
  app.kubernetes.io/component: api-gateway
  app.kubernetes.io/part-of: serverless-agentic-platform

