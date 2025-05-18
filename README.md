# idp-concept

## Project Goal

The goal of this project is to create a platform that, based on a **single source of truth**, can generate the necessary Kubernetes manifests to deploy one or more projects in different ways.

This approach prevents being locked into a specific technology. For example, if we use `helmfile` and generate YAML manifests with Go templating, we are tied to that technology. While this might be acceptable for deploying from a client to a Kubernetes cluster without using GitOps, what happens if the technology evolves and a better solution appears? Or what if we decide to implement GitOps? In that case, we would have to rewrite everything from scratch.

Furthermore, the development team would face challenges that shouldn't be their concern, such as constantly creating Helm packages, dealing with versioning issues, etc. It's also important to note that the version used in development is not fixed—it evolves continuously and may include components that won't go into production. Infrastructure may also differ between environments (e.g., a single database instance in development).

With this project, we aim to define a **core configuration using [KCL](https://www.kcl-lang.io/)**. From this core, we can deploy in different ways, across various environments, and over different timeframes.

Whenever possible, we will try to generate plain YAML files. This has two main advantages: it speeds up the deployment process and avoids the need to install plugins to make our platform compatible with specific manifest generation tools (like `kustomize`, `helm`, `helmfile`, `kusion`, etc.).

In addition to generating manifests for use with client-side technologies (such as `kustomize` or `helm`), this platform will also be capable of generating the necessary CRDs when using Kubernetes-native technologies like `Crossplane` or `ArgoCD`.


```
chmod +x <local_path_to_project>/idp-concept/platform_cli/koncept
```

```
mkdir -p ~/.local/bin
ln -s <local_path_to_project>/idp-concept/platform_cli/koncept ~/.local/bin/koncept
```

then you can execute:

from for example:

from idp-concept/projects/video_streaming/releases/helmfile/berlin/v1_0_0_berlin:

```
koncept render helmfile
```

from idp-concept/projects/video_streaming/pre_releases/gitops/site_one/generators/kafka_video_consumer_mongodb_python/dev

```
koncept render argocd
```

from idp-concept/projects/video_streaming/releases/kusion/berlin/v1_0_0_berlin/default

```
koncept render kusion
```




