# Serverless Agentic Governance Controller

[![CI/Lint/Test](https://github.com/brianmlasky/serverless-agentic-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/brianmlasky/serverless-agentic-platform/actions/workflows/ci.yml)
[![Security Scan](https://github.com/brianmlasky/serverless-agentic-platform/actions/workflows/security.yml/badge.svg)](https://github.com/brianmlasky/serverless-agentic-platform/actions/workflows/security.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Python 3.10+](https://img.shields.io/badge/Python-3.10%2B-blue)](https://www.python.org/downloads/)

**Real-time cost guardrails for AI workloads on GKE**

An event-driven controller that prevents "token runaway" in LLM applications by enforcing budget policies and autonomously terminating expensive pods. Built with Python AsyncIO, Kyverno admission control, and Kubernetes RBAC.

---

## 🎯 Problem

When you deploy LLM agents on Kubernetes:
- A single misconfigured prompt loop can cost $10k+ in minutes
- By the time you see the bill, damage is done
- You have no real-time controls to stop it

## ✅ Solution

This controller:
1. **Detects** token usage in real-time
2. **Evaluates** against budget policies
3. **Enforces** via Kyverno (pre-execution) + RBAC
4. **Remediates** autonomously (kill-switch pod deletion)
5. **Audits** every decision for compliance

---

## 🚀 Quick Start

### Prerequisites
- GKE 1.27+ with Workload Identity
- `kubectl`, `gcloud` CLI
- Cluster admin access

### Deploy (3 steps)

```bash
# 1. Clone & navigate
git clone https://github.com/brianmlasky/serverless-agentic-platform.git
cd serverless-agentic-platform

# 2. Set environment
export PROJECT_ID=$(gcloud config get-value project)
export CLUSTER_NAME="your-cluster"
export REGION="us-central1"

# 3. Install
bash scripts/install.sh

# Verify
kubectl get pods -n governance-system

Test It
bash


# Deploy a test workload
kubectl create namespace test-llm
kubectl label namespace test-llm governed=true cost-center=team-a

# Apply test pod
kubectl apply -f examples/test-pod.yaml

# Watch governance in action
kubectl logs -n governance-system -f -l app=governance-controller
🏗️ Architecture


[AI Workloads] 
    ↓ telemetry (tokens, cost)
[Governance Controller] (Python AsyncIO)
    ↓ policy evaluation (budget, quota)
[Kyverno + RBAC] (admission control)
    ↓ enforcement decision
[Remediation] (pod deletion, quarantine)
    ↓
[Audit Log] (compliance trail)
Key Components



Component	Purpose	Tech
Event Ingestion	Receive token/cost signals	Python httpx, event queue
Policy Evaluation	Check budget & quotas	Custom evaluator logic
Admission Control	Pre-execution gates	Kyverno ClusterPolicy
Remediation	Kill expensive pods	Kubernetes API delete
State Persistence	Restart-safe decisions	ConfigMap snapshots
Observability	Structured logging & metrics	JSON logs, Prometheus
📦 Installation
Step 1: Verify Prerequisites
bash


kubectl version --short
# Expected: v1.27+

gcloud container clusters describe $CLUSTER_NAME --region=$REGION | grep workloadPool
# Expected: workloadPool: PROJECT_ID.svc.id.goog
Step 2: Install Kyverno (Policy Engine)
bash


helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --version 1.10.0
Step 3: Set Up Workload Identity
bash


# Create GCP service account
gcloud iam service-accounts create governance-controller \
  --display-name="Governance Controller"

# Grant minimal permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:governance-controller@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"

# Create namespace & KSA
kubectl create namespace governance-system
kubectl create serviceaccount governance-controller -n governance-system

# Bind KSA to GSA
gcloud iam service-accounts add-iam-policy-binding \
  "governance-controller@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[governance-system/governance-controller]"

# Annotate KSA
kubectl patch serviceaccount governance-controller \
  -n governance-system \
  -p "{\"metadata\": {\"annotations\": {\"iam.gke.io/gcp-service-account\": \"governance-controller@${PROJECT_ID}.iam.gserviceaccount.com\"}}}"
Step 4: Deploy Controller
bash


kubectl apply -f k8s/governance/rbac.yaml
kubectl apply -f k8s/governance/controller-deployment.yaml
kubectl apply -f k8s/policies/
Step 5: Label Namespaces
bash


kubectl label namespace default governed=true cost-center=platform
kubectl label namespace test-llm governed=true cost-center=engineering
⚙️ Configuration
Environment Variables
bash


# Budget enforcement
BUDGET_THRESHOLD_USD=1000            # Monthly limit
WARNING_THRESHOLD_PERCENT=75         # Alert at 75%
KILL_SWITCH_ENABLED=true             # Auto-terminate violators

# Event processing
BATCH_SIZE=10
BATCH_TIMEOUT_SECONDS=5

# Kubernetes
KUBECONFIG=/var/run/secrets/kubernetes.io/serviceaccount/
WATCH_INTERVAL_SECONDS=30
STATE_CONFIGMAP=governance-state
STATE_NAMESPACE=governance-system

# Observability
LOG_LEVEL=INFO
LOG_FORMAT=json
METRICS_PORT=8080
ConfigMap Setup
bash


kubectl create configmap governance-config -n governance-system \
  --from-literal=BUDGET_THRESHOLD_USD=1000 \
  --from-literal=KILL_SWITCH_ENABLED=true \
  --from-literal=LOG_LEVEL=INFO
💡 Usage
How It Works
Your workload emits telemetry:
json


{
  "pod_name": "llm-agent-001",
  "namespace": "production",
  "tokens_used": 5432,
  "cost_usd": 0.54,
  "timestamp": "2025-01-15T14:32:10Z"
}
Controller receives and evaluates:

Checks cumulative cost against budget
Evaluates quota limits
Assesses risk (anomaly detection)
If policy violated:

Kyverno blocks new pod creation
Controller deletes offending pod
Event logged for audit
Result: Cost overage prevented in <100ms

Example: Governance in Action
bash


# Deploy a compliant workload
kubectl apply -f examples/workload-compliant.yaml
# → Pod runs normally, cost tracked

# Deploy a runaway workload (exceeds budget)
kubectl apply -f examples/workload-runaway.yaml
# → Controller detects overage
# → Pod terminated immediately
# → Audit log created

# Check governance logs
kubectl logs -n governance-system -l app=governance-controller | grep "runaway"
🧪 Testing
Unit Tests
bash


# Install dependencies
pip install -r requirements.txt

# Run tests
pytest src/tests/ -v --cov=src --cov-report=term-missing

# Expected: >80% coverage, all tests pass
Integration Tests (Requires GKE)
bash


pytest src/tests/test_integration.py -v -s

# Validates:
# - Pod creation/deletion
# - ConfigMap state persistence
# - Kyverno policy enforcement
# - RBAC authorization
Load Test
bash


bash scripts/load-test.sh --duration=5m --qps=100

# Measures:
# - Event processing latency (p50, p95, p99)
# - Controller memory/CPU
# - Throughput (events/sec)
🔐 Security
RBAC Principle: Least Privilege
Controller can only:

Read pods in namespaces labeled governed=true
Delete pods (for kill-switch)
Patch pods (for quarantine labels)
Read ConfigMaps in governance-system
Controller cannot:

Access secrets
Modify RBAC rules
Modify Kyverno policies
Escalate privileges
Workload Identity
No GCP service account keys stored in cluster
KSA bound to GSA via GKE Workload Identity
Minimal IAM roles: logging.logWriter, monitoring.metricWriter
Vulnerability Scanning
bash


# Scan dependencies
safety check

# Scan code for issues
bandit -r src/

# Scan Docker image
trivy image governance-controller:latest --severity HIGH,CRITICAL
📂 Project Structure


serverless-agentic-platform/
├── README.md
├── LICENSE (Apache 2.0)
├── CONTRIBUTING.md
├── SECURITY.md
├── requirements.txt
├── Dockerfile
├── Makefile
├── .github/workflows/
│   ├── ci.yml              # Unit tests + linting
│   ├── security.yml        # Bandit, Semgrep, dependencies
│   └── deploy.yml          # Build & push to GCR
├── scripts/
│   ├── install.sh          # One-command deployment
│   ├── uninstall.sh        # Cleanup
│   ├── load-test.sh        # Load testing
│   └── demo.sh             # End-to-end walkthrough
├── k8s/
│   └── governance/
│       ├── rbac.yaml
│       ├── controller-deployment.yaml
│       ├── state-configmap.yaml
│       └── policies/
│           ├── admission-policy.yaml  # Kyverno ClusterPolicy
│           └── audit-policy.yaml
├── src/
│   ├── controller.py       # Main async event loop
│   ├── config.py           # Configuration
│   └── governance/
│       ├── evaluator.py    # Budget/quota logic
│       ├── enforcer.py     # Remediation
│       ├── state.py        # ConfigMap persistence
│       └── models.py       # Data classes
│   └── tests/
│       ├── test_evaluator.py
│       ├── test_enforcer.py
│       ├── test_state.py
│       ├── test_integration.py
│       └── test_load.py
└── examples/
    ├── workload-compliant.yaml
    ├── workload-runaway.yaml
    └── test-pod.yaml
🤝 Contributing
See CONTRIBUTING.md [blocked] for guidelines.

Code Standards
bash


# Format & lint before commit
black src/ --line-length=100
isort src/
flake8 src/ --max-line-length=100
mypy src/ --ignore-missing-imports
pytest src/tests/ -q
🗺️ Roadmap
 Multi-cloud (AWS EKS, Azure AKS)
 ML-driven anomaly detection
 Grafana dashboard templates
 Slack/Teams alerts
 Cost allocation by team
 Budget forecasting
📄 License
Apache 2.0 — see LICENSE [blocked]

👨‍💼 Author
Brian Lasky — Cloud Architect & SRE
[GitHub](https://github.com/brianmlasky)| [LinkedIn](https://www.linkedin.com/in/brian-lasky-67464086/)
[Portfolio](https://www.brian-lasky.com/)

🆘 Support
Issues: GitHub Issues
Docs: See docs/ [blocked] folder
Security: SECURITY.md [blocked]
Status: Production Ready | Last Updated: January 2025 | Maintained: Yes



