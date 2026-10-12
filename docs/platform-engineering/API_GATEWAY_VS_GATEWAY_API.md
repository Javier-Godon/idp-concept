# API Gateway (APISIX) vs Gateway API (Envoy Gateway)

Two names that sound alike but are different things. The platform uses **both**, each for what it does best.

| | **Gateway API** | **API gateway** |
|---|---|---|
| What it is | A Kubernetes *standard* (CRDs: `Gateway`, `HTTPRoute`, ...) for describing how traffic enters the cluster | A *product category*: a reverse proxy that manages APIs (auth, rate limits, rewrites, transformations, ...) |
| In this platform | **Envoy Gateway** implements it: `gateway-system/platform-gateway` | **Apache APISIX 3.19** |
| Question it answers | "Which hostname/path reaches which Service, over TLS?" | "How is each REST API exposed, protected and shaped?" |
| Configured with | `HTTPRoute` (builders/route.k, `route` on `WebAppModule`) | `ApisixRoute` (builders/apisix_route.k), declared next to the app |
| Typical consumers | Argo CD, Keycloak, Valkey Admin, Nexus, Swagger, ... web UIs and tools | The REST API(s) of the ERP |

## How they work together

Envoy Gateway stays the **only edge** (ports 80/443, TLS, the hostname `bluesolution.es`). Paths that belong to
the REST API are handed to APISIX; everything else keeps going straight to its Service.

```text
Internet / browser
        │  https://bluesolution.es
        ▼
┌──────────────────────────────────────────────┐
│ Envoy Gateway  (gateway-system/platform-gateway) │   Gateway API: TLS, host, path → Service
└──────────────────────────────────────────────┘
   │ /argocd          → argocd-server
   │ /iam             → Keycloak
   │ /valkey-admin    → Valkey Admin
   │ /nexus           → Nexus
   │
   │ /api, /api/*     → erp-apisix-gateway:80          (APISIX data plane)
   │ /apisix          → 302 /ui/
   │ /ui, /apisix/admin → erp-apisix-admin:9180        (APISIX Admin UI / Admin API)
   ▼
┌──────────────────────────────────────────────┐
│ APISIX (ns apisix) + etcd + ingress-controller │   API gateway: per-API policy
│  ApisixRoute erp-backend: /api/* → rewrite    │
│  to /shopping/* → Service erp-backend:8089    │
└──────────────────────────────────────────────┘
        ▼
   erp-backend (ns erp-backend)
```

* **Do you need Gateway API for `/api`?** Yes, for the *first hop*. Something has to own ports 80/443 and TLS;
  that is Envoy Gateway. A single `HTTPRoute` (`erp-apisix-proxy`, rendered by the `XAPIGateway` composition)
  forwards `/api` to the APISIX Service. You do not write it by hand.
* **Do you need APISIX for the UIs?** No. Argo CD, Valkey, Keycloak, ... stay on `HTTPRoute`s. Only REST APIs
  go through APISIX. The APISIX Admin UI itself is published by Envoy (it is a web UI).
* **Where is each route declared?**
  * Edge (hostname/path → Service): `HTTPRoute`.
  * API (path → backend + plugins): `ApisixRoute`, reconciled by the Apache `apisix-ingress-controller`
    (the operator) into APISIX's etcd. No manual calls to the Admin API are needed.
* **Why the APISIX controller has Gateway API disabled:** the subchart can also act as a Gateway API
  controller; that is turned off (`disableGatewayAPI`) so Envoy Gateway remains the single Gateway API
  implementation and no second `GatewayClass` competes with it.

## Public URLs (dev)

| URL | Served by |
|---|---|
| `https://bluesolution.es/api/...` | APISIX → erp-backend (`/api/x` is rewritten to `/shopping/x`) |
| `https://bluesolution.es/apisix` | redirect to the APISIX Admin UI |
| `https://bluesolution.es/ui/` | APISIX Admin UI (log in with the admin key) |

The embedded Admin UI is hardcoded to `/ui/*` and calls `/apisix/admin/*`; it cannot be mounted under a
sub-path, so `/apisix` is a friendly entry point that redirects to `/ui/`. The Admin API is protected by the key
in the `apisix-admin-keys` Secret (never committed) and by the `adminAllowCidrs` allow-list.

## Adding another API behind APISIX

```kcl
import framework.builders.apisix_route as apisix_route

extraManifests = [apisix_route.build_apisix_route(apisix_route.ApisixRouteSpec {
    name = "orders"
    namespace = "orders"
    serviceName = "orders"
    servicePort = 8080
    publicPath = "/api/orders"   # published prefix; must be under a prefix Envoy forwards (/api)
})]
```

Plugins (JWT/Keycloak auth, rate limiting, CORS) are added to the `ApisixRoute` `plugins` list; see the
[APISIX plugin hub](https://apisix.apache.org/docs/apisix/plugins/limit-count/).

## etcd storage: Ceph, Longhorn or local?

APISIX keeps all its configuration in etcd (the chart bundles one, for development/testing).

* **minikube/dev:** use the cluster's `local-path` provisioner (`apisixEtcdStorageClass` in the site config).
  Do not install Ceph or Longhorn on a single-node minikube just for etcd: Ceph needs raw devices and several
  OSDs, Longhorn needs `open-iscsi` and replicas, and both cost far more than a 2Gi etcd volume. (On this
  cluster the `standard` class has no running provisioner, so etcd stayed `Pending`.)
* **Production:** etcd needs low-latency fsync and consistency. Ceph RBD (`rook-ceph-block`) works when backed
  by fast media (SSD/NVMe pools); a local-NVMe class can be faster. Keep 3 etcd replicas and set
  `etcdStorageClass` in the production site config. For real production prefer an external etcd (or the
  operator-managed one) and point the chart's `externalEtcd` at it.
* Longhorn is a fine second option for non-Ceph clusters; only the storage class name changes.

## Operational notes

1. Create the Admin keys Secret before the release can start (the namespace is created by the composition,
   or create it yourself):
   `kubectl -n apisix create secret generic apisix-admin-keys --from-literal=admin="$(openssl rand -hex 16)" --from-literal=viewer="$(openssl rand -hex 16)"`
2. `ApisixRoute` is a CRD installed by the APISIX release, so the `erp-apps-dev` Argo CD application can only
   sync the route once `erp-dev` has reconciled the `XAPIGateway`; Argo CD retries automatically.
3. `adminAllowCidrs` must contain the pod network CIDR (minikube default `10.244.0.0/16`).
4. The bundled etcd image is the Bitnami *legacy* image pinned to `3.6.4-debian-12-r4` because the chart
   default tag is `latest`. Plan an external etcd for production.
