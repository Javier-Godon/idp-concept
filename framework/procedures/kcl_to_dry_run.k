"""
Dry-run procedure for planning and governance previews.

Produces a compact, render-safe planning document with:
- merged configuration snapshot
- module inventory and dependency edges
- Helmfile release projection (name/namespace/chart/needs)
- Crossplane V2 metadata and sequencer preview
"""

import procedures.kcl_to_helmfile as helmfile_proc
import procedures.kcl_to_crossplane as crossplane_proc

_dep_namespace = lambda dep: any -> str {
    "cluster" if dep.kind == "Namespace" else (dep.namespace if dep.namespace else "cluster")
}

_module_ref = lambda dep: any -> str {
    "${dep.kind}:${_dep_namespace(dep)}:${dep.name}"
}

_module_summary = lambda module_kind: str, module: any -> any {
    {
        name = module.name
        namespace = module.namespace
        kind = module_kind
        leaders = ["${leader.kind}:${leader.name}" for leader in (module.leaders if module.leaders else [])]
        dependsOn = [_module_ref(dep) for dep in (module.dependsOn if module.dependsOn else [])]
    }
}

_dependencies = lambda modules: [any] -> [any] {
    [
        {
            from = "${module.namespace}/${module.name}"
            to = "${_dep_namespace(dep)}/${dep.name}"
            dependencyKind = dep.kind
        }
        for module in (modules if modules else [])
        for dep in (module.dependsOn if module.dependsOn else [])
    ]
}

_helmfile_release_projection = lambda release: any -> any {
    {
        name = release.name
        namespace = release.namespace
        chart = release.chart
        needs = release.needs if release.needs else []
    }
}

# Calculate resource footprint from manifests
_extract_resource_requests = lambda module: any -> any {
    _leaders = module.leaders if module.leaders else []
    _manifest_count = len(module.manifests) if module.manifests else 0
    {
        moduleCount = 1
        manifestCount = _manifest_count
        estimatedReplicas = 1  # placeholder; actual replicas come from deployment/statefulset specs
        storage = {
            pvcCount = len([m for m in (module.manifests if module.manifests else []) if m.kind == "PersistentVolumeClaim"])
        }
    }
}

_extract_resource_value = lambda value: any -> int {
    """Convert resource strings like '500m', '1Gi', '100' to integers or 0"""
    # Simple approach: convert to string, then parse using conditional expressions
    _str = str(value) if value else "0"
    _m_val = _str.rstrip("m")
    _gi_val = _str.rstrip("Gi")
    int(_m_val) if (_str.endswith("m") and _m_val) else (int(_gi_val) * 1024 if (_str.endswith("Gi") and _gi_val) else (int(_str) if _str.isdigit() else 0))
}

_calculate_resource_footprint = lambda manifests: [any] -> any {
    """Extract CPU/memory requirements from Deployment and StatefulSet specs - simplified functional approach"""
    _workload_manifests = [m for m in (manifests if manifests else []) if m.kind in ["Deployment", "StatefulSet"]]

    # Helper to get all containers - using conditional expression
    _get_containers = lambda wl: any -> [any] {
        wl.spec.template.spec.containers if (wl.spec and wl.spec.template and wl.spec.template.spec and wl.spec.template.spec.containers) else []
    }

    _get_replicas = lambda wl: any -> int {
        wl.spec.replicas if (wl.spec and wl.spec.replicas) else 1
    }

    # Collect all resources
    _all_container_data = [
        {
            cpu = _extract_resource_value(c.resources.requests.get("cpu", 0)) * _get_replicas(_w) if (c.resources and c.resources.requests) else 0
            memory = _extract_resource_value(c.resources.requests.get("memory", 0)) * _get_replicas(_w) if (c.resources and c.resources.requests) else 0
            hasMissing = not (c.resources and c.resources.requests)
            workloadName = _w.metadata.name if _w.metadata else "unknown"
        }
        for _w in _workload_manifests
        for c in _get_containers(_w)
    ]

    _total_cpu = sum([c.cpu for c in _all_container_data])
    _total_memory = sum([c.memory for c in _all_container_data])
    _warnings = ["${c.workloadName}: missing resource requests" for c in _all_container_data if c.hasMissing]

    # Calculate storage from PVCs
    _pvc_manifests = [m for m in (manifests if manifests else []) if m.kind == "PersistentVolumeClaim"]
    _storage_values = [
        _extract_resource_value(pvc.spec.resources.requests.get("storage", 0))
        for pvc in _pvc_manifests
        if pvc.spec and pvc.spec.resources and pvc.spec.resources.requests
    ]
    _total_storage = sum(_storage_values) if _storage_values else 0

    {
        estimatedCpuMillis = _total_cpu
        estimatedMemoryMb = _total_memory
        estimatedStorageGb = _total_storage
        estimatedNodesSmall = int((_total_cpu + 1000) / 2000) if _total_cpu > 0 else 0
        estimatedNodesMedium = int((_total_cpu + 4000) / 8000) if _total_cpu > 0 else 0
        warnings = _warnings
    }
}

_resource_footprint = lambda modules: [any] -> any {
    _all_manifests = [m for mod in (modules if modules else []) for m in (mod.manifests if mod.manifests else [])]
    _pvc_count = len([m for m in _all_manifests if m.kind == "PersistentVolumeClaim"])
    _deploy_count = len([m for m in _all_manifests if m.kind == "Deployment"])
    _statefulset_count = len([m for m in _all_manifests if m.kind == "StatefulSet"])
    _daemonset_count = len([m for m in _all_manifests if m.kind == "DaemonSet"])
    _resources = _calculate_resource_footprint(_all_manifests)

    {
        manifestCount = len(_all_manifests)
        deploymentCount = _deploy_count
        statefulsetCount = _statefulset_count
        daemonsetCount = _daemonset_count
        persistentVolumeClaimCount = _pvc_count
        estimatedWorkloads = _deploy_count + _statefulset_count + _daemonset_count
        cpuRequest = {
            millis = _resources.estimatedCpuMillis
            estimatedNodes = _resources.estimatedNodesSmall
        }
        memoryRequest = {
            mb = _resources.estimatedMemoryMb
        }
        storageInfo = {
            pvcCount = _pvc_count
            estimatedGb = _resources.estimatedStorageGb
            if _pvc_count > 0:
                warning = "Storage class availability should be verified before deployment"
        }
        warnings = _resources.warnings
    }
}

generate_dry_run_from_stack = lambda input_stack: any, project_name: str, version: str = "1.0.0" -> any {
    _helmfile = helmfile_proc.generate_helmfile_from_stack(input_stack, "./charts")
    _crossplane = crossplane_proc.generate_crossplane_from_render_stack(input_stack, project_name, version)
    _all_modules = (input_stack.components if input_stack.components else []) + (input_stack.accessories if input_stack.accessories else [])
    _footprint = _resource_footprint(_all_modules)

    {
        apiVersion = "koncept.bluesolution.es/v1alpha1"
        kind = "DryRunPlan"
        metadata = {
            name = "${project_name}-dry-run"
            project = project_name
            version = version
            generatedBy = "koncept dry-run"
        }
        spec = {
            mergedConfigurations = input_stack.instanceConfigurations
            stackMetadata = input_stack.metadata if input_stack.metadata else {}
            inventory = {
                namespaces = [ns.name for ns in (input_stack.k8snamespaces if input_stack.k8snamespaces else [])]
                components = [_module_summary("component", c) for c in (input_stack.components if input_stack.components else [])]
                accessories = [_module_summary("accessory", a) for a in (input_stack.accessories if input_stack.accessories else [])]
            }
            dependencies = _dependencies(_all_modules)
            resourceFootprint = _footprint
            outputs = {
                helmfile = {
                    releaseCount = len(_helmfile.releases) if _helmfile.releases else 0
                    releases = [_helmfile_release_projection(r) for r in (_helmfile.releases if _helmfile.releases else [])]
                }
                crossplane = {
                    metadata = _crossplane.metadata
                    sequencerRules = _crossplane.composition.spec.pipeline[1].input.rules if _crossplane.metadata.sequencerRules > 0 else []
                    prerequisites = ["${r.kind}/${r.metadata.name}" for r in (_crossplane.prerequisites if _crossplane.prerequisites else [])]
                }
            }
        }
    }
}





