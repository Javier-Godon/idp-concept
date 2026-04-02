# Work Matrix by User Profile

> Maps every IDP evolution phase to the responsible user profile and their specific tasks.

---

## Developer

| Phase | Task | Input | Output |
|---|---|---|---|
| 4 | Use `koncept validate` before rendering | CLI command | Validation result |
| 4 | Use `koncept render helmfile` for param charts | CLI command | Helm charts + values.yaml |
| 4 | Create per-environment value overrides | `env/<env>.yaml` files | Customized deployments |
| 5 | Report configuration issues via `koncept validate` | CLI output | Bug reports |
| 6 | Configure operator-managed database resources | Site/tenant YAML configs | Custom DB settings per env |
| 7 | Use `koncept render kustomize` | CLI command | Kustomize overlays |
| 7 | Use `koncept render timoni` (experimental) | CLI command | Timoni CUE module |

---

## Platform Engineer — High-Level

| Phase | Task | Input | Output |
|---|---|---|---|
| 1 | Fix hardcoded secrets in video_streaming modules | Module `.k` files | Secure `secretKeyRef` patterns |
| 1 | Add `gitRepoUrl` to project configurations | `BaseConfigurations` extension | Configurable ArgoCD sources |
| 2 | Create project-specific `values_builder.k` | Component configs | Generated `values.yaml` |
| 2 | Create project-specific `helmfile_builder.k` | Stack definition | Generated `helmfile.yaml` |
| 2 | Define per-environment value overrides | `env/*.yaml` files | Environment-specific configs |
| 3 | Migrate video_streaming modules to template pattern | Raw modules | Template-based modules |
| 4 | Write developer quickstart documentation | Architecture knowledge | `DEVELOPER_QUICKSTART.md` |
| 6 | Create operator-backed modules (PostgreSQL, Redis) | Operator CRDs + templates | Production database modules |
| 6 | Add Bitnami chart wrappers to stacks | ThirdParty module configs | Third-party integrations |
| 6 | Configure ExternalSecrets for vault integration | Secret store configs | Externalized secrets |

---

## Platform Engineer — Low-Level

| Phase | Task | Input | Output |
|---|---|---|---|
| 1 | Fix `imagePullPolicy` defaults | `database.k` | Consistent defaults |
| 1 | Fix accessory.k code style | `accessory.k` | Clean formatting |
| 2 | Implement `kcl_to_helmfile.k` procedure | Stack schema | Helmfile YAML generation |
| 2 | Expand `kcl_to_helm.k` with Chart + Values generation | Component schema | Helm Chart generation |
| 2 | Create Helm value extraction lambdas | Component manifests | `HelmValues` schema |
| 2 | Create static Helm template files | Builder patterns | `templates/*.tpl` |
| 2 | Update CLI `koncept render helmfile` flow | Nushell script | Full Helmfile pipeline |
| 3 | Create `EnvVar` schema + type safety | `common.k` | Typed env declarations |
| 3 | Add `check` validation blocks to builders | Builder schemas | Compile-time validation |
| 3 | Document justified `any` types | Framework models | Clear intent markers |
| 3 | Create KCL test infrastructure | Test patterns | `framework/tests/` |
| 4 | Implement `koncept validate` | CLI command | Pre-render validation |
| 4 | Implement `koncept init` scaffolding | CLI command | Project scaffolding |
| 4 | Remove hardcoded builder filenames | CLI refactor | Configurable builders |
| 5 | Implement `kcl_to_argocd.k` | Stack schema | ArgoCD Application CRDs |
| 5 | Create NetworkPolicy builder | Builder pattern | Network isolation |
| 5 | Create PDB builder | Builder pattern | HA guarantees |
| 5 | Design secret management schemas | Security patterns | Formalized secret refs |
| 6 | Import operator CRDs → KCL schemas | Operator CRDs | KCL schema definitions |
| 6 | Create PostgreSQL/Redis/MongoDB templates | Operator models | Production templates |
| 6 | Create ThirdPartyHelmSpec schema | Framework models | Helm chart integration |
| 6 | Create Bitnami chart catalog templates | Bitnami charts | IDP wrappers |
| 6 | Create ExternalSecret builder/template | Security models | Secret management |
| 7 | Implement `kcl_to_kustomize.k` procedure | Stack schema | Kustomize output |
| 7 | Implement `kcl_to_timoni.k` procedure | Stack schema | Timoni CUE module output |
| 7 | Implement KCL plugin integration layer | helm-kcl/kustomize-kcl | Mutation pipeline |
| 7 | Create OCI artifact publishing pipeline | Nushell CLI | `koncept publish` command |

---

## Cross-Cutting Responsibilities

| Area | Developer | High-Level PE | Low-Level PE |
|---|---|---|---|
| **Configuration** | Site/tenant YAML values | Stack composition, module selection | Schema design, validation rules |
| **CLI** | Use commands | Report issues, request features | Implement commands |
| **Testing** | Report failures | Integration testing per project | Unit tests, TDD, kubeconform |
| **Security** | Use `secretKeyRef` in configs | Configure ExternalSecrets | Design secret schemas/builders |
| **Documentation** | Read quickstart guide | Write project-specific docs | Write framework docs |
| **Output Formats** | Run render commands | Choose format per project | Implement procedures |
