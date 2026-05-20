# Serverless Agentic Governance Controller

## Overview
An autonomous, event-driven SRE platform designed to enforce fiscal guardrails on AI-driven Kubernetes workloads. This project demonstrates real-time observability, automated budget remediation, and policy-as-code enforcement on GKE.

## Architecture
```mermaid
graph TD
    subgraph Infrastructure
        AG[API Gateway]
        TG[Triggered Workload]
    end
    subgraph Governance
        CM[(Governance ConfigMap)]
        GC[Governance Controller Agent]
    end
    subgraph Remediation
        K8S[Kubernetes API]
        Logs[Structured Logs]
    end
    AG -- "1. Logs Event" --> CM
    GC -- "2. Polls State" --> CM
    GC -- "3. Calculates Spend" --> GC
    GC -- "4. Threshold Breach" --> K8S
    K8S -- "5. Kill/Scale Command" --> TG
    GC -- "6. Emit Telemetry" --> Logs
