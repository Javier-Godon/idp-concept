# Policy-as-Code Admission Parity — Kyverno & Conftest

> Mapping `koncept policy check` rules to cluster admission controllers (Kyverno, OPA Gatekeeper) and CI/CD validation (Conftest), ensuring consistent enforcement from render-time through deployment.

---

## Overview

The `koncept policy check` CLI gate runs **before rendering**, catching policy violations early in the development workflow. For production clusters, the same rules must be enforced **at admission time**, so no manifest can bypass policy even if hand-edited or bypassed in CI.

This document maps the 7 platform policies to:
1. **Kyverno ClusterPolicy** (preferred: simpler, Kubernetes-native)
2. **OPA Gatekeeper + Rego rules** (alternative: more flexible)
3. **Conftest policies** (CI/CD: validates rendered YAML before deployment)

---

## Policy Mapping Matrix

| `koncept policy check` Rule | Kyverno ClusterPolicy | OPA Rule | Conftest Policy | Enforcement |
|---|---|---|---|---|
| **1. No privileged / hostNetwork** | `restrict-privileged` | `deny_privileged` | `deny_privileged` | ✅ Critical (error) |
| **2. No 'latest' tags** | `require-image-digest` | `deny_latest_tags` | `require_pinned_images` | ✅ Critical (error) |
| **3. Resources required (Tier-1)** | `require-requests-limits` | `require_resources` | `require_resources_tier1` | ✅ Critical (error) |
| **4. Ownership labels** | `require-ownership` | `require_labels` | `require_labels_ownership` | ⚠️ Warning (configurable) |
| **5. Secret refs (no literals)** | `require-secret-refs` | `require_secret_refs` | `require_secret_refs` | ✅ Critical (error) |
| **6. Explicit namespace** | `require-namespace` | `require_namespace` | `require_namespace` | ⚠️ Warning (configurable) |
| **7. NetworkPolicy (default-deny)** | `require-network-policy` | `require_network_policy` | `require_network_policy` | ⚠️ Warning (configurable) |

---

## Part 1: Kyverno ClusterPolicies

### Installation
```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace \
  --set config.webhooks=[{namespaceSelector={matchExpressions=[{key: policy.kyverno.io/enforce, operator: In, values: [audit]}]}}]
```

### Policy 1: Deny Privileged & Host Access
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-privileged-host-access
spec:
  validationFailureAction: audit  # use "enforce" for hard gate
  rules:
  - name: privileged
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Privileged containers not allowed"
      pattern:
        spec:
          containers:
          - securityContext:
              privileged: false
  - name: hostNetwork
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "hostNetwork not allowed"
      pattern:
        spec:
          hostNetwork: false
  - name: hostPID
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "hostPID not allowed"
      pattern:
        spec:
          hostPID: false
```

### Policy 2: Require Image Digest or Specific Tag
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-digest
spec:
  validationFailureAction: audit
  rules:
  - name: require-digest-or-semver
    match:
      resources:
        kinds:
        - Deployment
        - StatefulSet
        - DaemonSet
    validate:
      message: "Images must be pinned to a digest or semantic version tag, not 'latest'"
      pattern:
        spec:
          template:
            spec:
              containers:
              - image: "!*:latest"
              initContainers:
              - image: "!*:latest"
```

### Policy 3: Require CPU/Memory Resources
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resources-limits
spec:
  validationFailureAction: audit
  rules:
  - name: require-limits-tier1
    match:
      resources:
        kinds:
        - Deployment
        - StatefulSet
        - DaemonSet
        labels:
          tier: tier-1
    validate:
      message: "Tier-1 workloads must specify CPU and memory requests and limits"
      pattern:
        spec:
          template:
            spec:
              containers:
              - resources:
                  requests:
                    memory: "?*"
                    cpu: "?*"
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

### Policy 4: Require Ownership Labels
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-ownership-labels
spec:
  validationFailureAction: audit
  rules:
  - name: require-owner
    match:
      resources:
        kinds:
        - Deployment
        - StatefulSet
        - DaemonSet
        labels:
          tier: tier-1
    validate:
      message: "Workloads must carry ownership label (e.g., app.kubernetes.io/owner)"
      pattern:
        metadata:
          labels:
            app.kubernetes.io/owner: "?*"
```

### Policy 5: Require Secret References
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-secret-refs
spec:
  validationFailureAction: audit
  rules:
  - name: forbid-secret-literals
    match:
      resources:
        kinds:
        - Deployment
        - StatefulSet
        - DaemonSet
    validate:
      message: "Secret-like environment variables (PASSWORD, TOKEN, KEY, SECRET) must use valueFrom.secretKeyRef, not literal values"
      pattern:
        spec:
          template:
            spec:
              containers:
              - env:
                - name: "PASSWORD|TOKEN|API_KEY|SECRET|PRIVATE_KEY"
                  value: "?*"  # fail if literal value exists
```

---

## Part 2: OPA Gatekeeper Rules (Rego)

### Installation
```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
```

### Rule 1: Require Image Digest (Rego)
```rego
package k8srequireddigest

violation[{"msg": msg}] {
    container := input.review.object.spec.template.spec.containers[_]
    image := container.image
    not contains(image, "@sha256:")
    endswith(image, ":latest")
    msg := sprintf("Image %v uses 'latest' tag; must be pinned to a digest or semver tag", [image])
}
```

### Rule 2: Deny Privileged (Rego)
```rego
package k8sdenyprivileged

violation[{"msg": msg}] {
    container := input.review.object.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("Privileged container %v not allowed", [container.name])
}
```

### Rule 3: Require Resources (Rego)
```rego
package k8srequireresources

violation[{"msg": msg}] {
    container := input.review.object.spec.template.spec.containers[_]
    resources := container.resources
    not resources.requests.cpu
    msg := sprintf("Container %v missing CPU request", [container.name])
}

violation[{"msg": msg}] {
    container := input.review.object.spec.template.spec.containers[_]
    resources := container.resources
    not resources.limits.cpu
    msg := sprintf("Container %v missing CPU limit", [container.name])
}
```

---

## Part 3: Conftest Policies (Rego for CI/CD)

### Install Conftest
```bash
curl -L -o conftest.tar.gz https://github.com/open-policy-agent/conftest/releases/download/v0.55.0/conftest_0.55_linux_x86_64.tar.gz
tar xzf conftest.tar.gz
sudo mv conftest /usr/local/bin/
```

### CI Job Example (GitHub Actions)
```yaml
- name: Validate with Conftest
  run: |
    conftest test \
      -p framework/policies/rego \
      -o json \
      output/kubernetes_manifests.yaml
```

### Rego Policy File (`framework/policies/rego/platform.rego`)
```rego
package main

import future.keywords.contains
import future.keywords.if

# Deny images without digest or semver pin
deny[msg] {
    container := input.spec.template.spec.containers[_]
    image := container.image
    endswith(image, ":latest")
    msg := sprintf("❌ Image %v uses unacceptable 'latest' tag", [image])
}

# Require resources for Tier-1
deny[msg] {
    labels := input.metadata.labels
    labels["tier"] == "tier-1"
    containers := input.spec.template.spec.containers
    container := containers[_]
    not container.resources.requests.cpu
    msg := sprintf("❌ Tier-1 workload %v missing CPU request", [input.metadata.name])
}

# Forbid secret literals
deny[msg] {
    container := input.spec.template.spec.containers[_]
    env := container.env[_]
    contains(env.name, ["PASSWORD", "TOKEN", "KEY", "SECRET"])
    env.value != null  # literal value exists
    msg := sprintf("❌ Secret variable %v uses literal value; use valueFrom.secretKeyRef", [env.name])
}

# Warn on missing ownership
warn[msg] {
    labels := input.metadata.labels
    not labels["app.kubernetes.io/owner"]
    msg := sprintf("⚠️  Workload %v missing ownership label", [input.metadata.name])
}
```

---

## Deployment Workflow

### Development (Local + CI)
1. Developer runs `koncept policy check --factory <dir>` locally
2. CI runs both `koncept policy check` and `conftest test` on rendered YAML
3. Policy violations block PR

### Staging/Production (Admission)
1. Manifests reach cluster API server
2. Kyverno webhook intercepts Pod/Deployment/StatefulSet/DaemonSet creates
3. ClusterPolicy validates against the mapped rules
4. Non-compliant resource is rejected (enforce) or logged (audit)

---

## Enforcement Strategy

| Phase | Tool | Mode | Action |
|---|---|---|---|
| Local dev | `koncept policy check` | Warnings + errors | Blocked (error), visible (warning) |
| CI/CD | `koncept policy check` + `conftest` | Errors | Blocked on error; PR blocked |
| Staging | Kyverno | **audit** | Logged, not blocked; safe to review |
| Production | Kyverno | **enforce** | Rejected; hard gate |

---

## Next Steps

1. **Deploy Kyverno to staging**: `kubectl apply -f kyverno-policies.yaml`
2. **Run in audit mode for 1–2 weeks**: collect violations without blocking
3. **Review violations**: audit logs in Kyverno → tune policies
4. **Switch to enforce**: once team is confident
5. **Link to CI**: Conftest runs before deployment, Kyverno catches hand-edited manifests

---

## References

- **Kyverno docs**: https://kyverno.io/docs/
- **OPA/Gatekeeper**: https://open-policy-agent.github.io/gatekeeper/
- **Conftest**: https://www.conftest.dev/
- **koncept policy check**: `koncept policy check --help`

