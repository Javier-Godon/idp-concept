# Cluster routes (apps outside this repository)

HTTPRoutes that replaced the ingress-nginx Ingresses of applications not managed by this
repository. They attach to the shared platform gateway (`gateway-system/platform-gateway`,
see `projects/platform`). Apply with:

```bash
kubectl apply -f delivery/cluster-routes/
```

| Route | Replaces Ingress | Listener |
|---|---|---|
| `cert-parser/cert-parser` | `cert-parser/cert-parser-ingress` | `http`, any host, `/prt-cert-parser` prefix stripped |

Notes:

- `railroad/railway` and `shopping/shopping-front` (and their namespaces) were removed from the cluster.
