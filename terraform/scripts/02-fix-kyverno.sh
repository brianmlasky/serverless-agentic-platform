#!/usr/bin/env bash
set -euo pipefail

KYVERNO_VERSION="3.2.6"
NAMESPACE="kyverno"

echo "════════════════════════════════════════════════════════════"
echo "  Kyverno Remediation — Version: ${KYVERNO_VERSION}"
echo "════════════════════════════════════════════════════════════"

echo ""
echo "▶ Step 1: Confirming missing CRDs..."
for crd in clusterpolicies.kyverno.io policies.kyverno.io; do
  if kubectl get crd "${crd}" &>/dev/null; then
    echo "  ✅ ${crd} — present"
  else
    echo "  ❌ ${crd} — MISSING"
  fi
done

echo ""
echo "▶ Step 2: Scaling down controllers..."
for deploy in kyverno-admission-controller kyverno-background-controller kyverno-cleanup-controller kyverno-reports-controller; do
  kubectl scale deployment "${deploy}" -n "${NAMESPACE}" --replicas=0 2>/dev/null && echo "  Scaled down ${deploy}" || true
done

echo ""
echo "▶ Step 3: Removing webhooks..."
kubectl delete mutatingwebhookconfiguration kyverno-resource-mutating-webhook-cfg kyverno-policy-mutating-webhook-cfg kyverno-verify-mutating-webhook-cfg 2>/dev/null && echo "  Removed mutating webhooks" || echo "  None found"
kubectl delete validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg kyverno-policy-validating-webhook-cfg kyverno-exception-validating-webhook-cfg 2>/dev/null && echo "  Removed validating webhooks" || echo "  None found"

echo ""
echo "▶ Step 4: Removing orphaned workloads..."
kubectl delete deployment kyverno-admission-controller kyverno-background-controller kyverno-cleanup-controller kyverno-reports-controller -n "${NAMESPACE}" 2>/dev/null && echo "  Deployments removed" || true
kubectl delete service kyverno-svc kyverno-svc-metrics kyverno-background-controller-metrics kyverno-cleanup-controller kyverno-cleanup-controller-metrics kyverno-reports-controller-metrics -n "${NAMESPACE}" 2>/dev/null && echo "  Services removed" || true

echo ""
echo "▶ Step 5: Configuring Helm repo..."
helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
helm repo update

echo ""
echo "▶ Step 6: Installing Kyverno ${KYVERNO_VERSION} via Helm..."
helm install kyverno kyverno/kyverno \
  --namespace "${NAMESPACE}" \
  --version "${KYVERNO_VERSION}" \
  --create-namespace \
  --set crds.install=true \
  --set crds.migration.enabled=true \
  --set admissionController.replicas=1 \
  --set backgroundController.enabled=true \
  --set backgroundController.replicas=1 \
  --set reportsController.enabled=true \
  --set reportsController.replicas=1 \
  --set cleanupController.enabled=true \
  --set cleanupController.replicas=1 \
  --set features.logging.verbosity=2 \
  --timeout 5m \
  --wait

echo "  Helm install complete"

echo ""
echo "▶ Step 7: Verifying CRDs..."
for crd in clusterpolicies.kyverno.io policies.kyverno.io cleanuppolicies.kyverno.io policyexceptions.kyverno.io; do
  if kubectl get crd "${crd}" &>/dev/null; then
    echo "  OK: ${crd}"
  else
    echo "  MISSING: ${crd}"
  fi
done

echo ""
echo "▶ Step 8: Waiting for admission-controller Ready..."
kubectl wait pod -n "${NAMESPACE}" -l app.kubernetes.io/component=admission-controller --for=condition=Ready --timeout=120s

echo ""
echo "▶ Final pod status:"
kubectl get pods -n "${NAMESPACE}"
echo "Done."
