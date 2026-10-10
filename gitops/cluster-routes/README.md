# Cluster routes (apps outside this repository)

HTTPRoutes that replaced the ingress-nginx Ingresses of applications not managed by this
repository. They attach to the shared platform gateway (`gateway-system/platform-gateway`,
see `projects/platform`). Apply with:

```bash
kubectl apply -f gitops/cluster-routes/
```

| Route | Replaces Ingress | Listener |
|---|---|---|
| `railroad/railway` | `railroad/railway-ingress` | `http` (was plain HTTP) |
| `shopping/shopping-front` | `shopping/shopping-front` | `https` (HTTP redirects to HTTPS) |
| `cert-parser/cert-parser` | `cert-parser/cert-parser-ingress` | `http`, any host, `/prt-cert-parser` prefix stripped |

Notes:

- `railway-ingress` used `rewrite-target: /` with `use-regex: true`, which rewrote every path to
  `/`; the HTTPRoute forwards paths unchanged. (The `railway-app` pods were crash-looping before the
  migration, so its behavior could not be compared.)
- `shopping/railway-service` is an `ExternalName` Service, which Envoy Gateway rejects as a backend;
  the route targets `railroad/railway-service` through a `ReferenceGrant`.
- The Ingress rate-limit and body-size annotations of `shopping-front` have no direct Gateway API
equivalent; add Envoy Gateway `BackendTrafficPolicy`/`ClientTrafficPolicy` if they are needed.
