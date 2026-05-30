package policy

import (
	"fmt"
	"strings"

	"gopkg.in/yaml.v3"
)

// Severity classifies a policy finding.
type Severity string

const (
	SeverityError   Severity = "error"
	SeverityWarning Severity = "warning"
)

// Finding is a single policy violation against a rendered manifest.
type Finding struct {
	Rule     string
	Severity Severity
	Kind     string
	Name     string
	Message  string
}

func (f Finding) String() string {
	target := f.Kind
	if f.Name != "" {
		target = f.Kind + "/" + f.Name
	}
	return fmt.Sprintf("[%s] %s (%s): %s", f.Severity, f.Rule, target, f.Message)
}

// Options toggles individual policy rules.
type Options struct {
	RequireResources bool
	RequireOwner     bool
}

// DefaultOptions enables the full baseline policy set.
func DefaultOptions() Options {
	return Options{RequireResources: true, RequireOwner: true}
}

// workloadKinds are the Tier-1 workload kinds that must carry resource
// requests/limits and ownership labels.
var workloadKinds = map[string]bool{
	"Deployment":  true,
	"StatefulSet": true,
	"DaemonSet":   true,
}

// Check parses a multi-document YAML stream and returns policy findings.
func Check(renderedYAML string, opts Options) ([]Finding, error) {
	var findings []Finding
	dec := yaml.NewDecoder(strings.NewReader(renderedYAML))
	for {
		var doc map[string]any
		if err := dec.Decode(&doc); err != nil {
			break
		}
		if len(doc) == 0 {
			continue
		}
		findings = append(findings, checkDoc(doc, opts)...)
	}
	return findings, nil
}

func checkDoc(doc map[string]any, opts Options) []Finding {
	var findings []Finding
	kind, _ := doc["kind"].(string)
	name := metadataName(doc)

	add := func(rule string, sev Severity, msg string) {
		findings = append(findings, Finding{Rule: rule, Severity: sev, Kind: kind, Name: name, Message: msg})
	}

	podSpec := podSpecOf(doc)
	if podSpec != nil {
		containers := containersOf(podSpec)

		// Rule: no privileged containers / privilege escalation / hostNetwork.
		if b, _ := podSpec["hostNetwork"].(bool); b {
			add("no-host-network", SeverityError, "pod sets hostNetwork: true")
		}
		for _, c := range containers {
			cname, _ := c["name"].(string)
			if sc, ok := c["securityContext"].(map[string]any); ok {
				if b, _ := sc["privileged"].(bool); b {
					add("no-privileged", SeverityError, fmt.Sprintf("container %q is privileged", cname))
				}
				if b, _ := sc["allowPrivilegeEscalation"].(bool); b {
					add("no-privilege-escalation", SeverityError, fmt.Sprintf("container %q allows privilege escalation", cname))
				}
			}

			// Rule: no latest / untagged images.
			image, _ := c["image"].(string)
			if image != "" {
				if tag := imageTag(image); tag == "" || tag == "latest" {
					add("no-latest-tag", SeverityError,
						fmt.Sprintf("container %q uses unpinned image %q (pin a specific version tag)", cname, image))
				}
			}

			// Rule: workloads require resource requests/limits.
			if opts.RequireResources && workloadKinds[kind] {
				if !hasResourceRequestsLimits(c) {
					add("require-resources", SeverityError,
						fmt.Sprintf("container %q is missing resources.requests/limits", cname))
				}
			}
		}
	}

	// Rule: workloads require ownership labels.
	if opts.RequireOwner && workloadKinds[kind] {
		if !hasOwnerLabel(doc) {
			add("require-owner", SeverityWarning,
				"workload is missing an ownership label (app.kubernetes.io/part-of or owner)")
		}
	}

	return findings
}

func metadataName(doc map[string]any) string {
	if md, ok := doc["metadata"].(map[string]any); ok {
		if n, ok := md["name"].(string); ok {
			return n
		}
	}
	return ""
}

// podSpecOf returns the pod spec for workload kinds (under spec.template.spec)
// or for a bare Pod (spec).
func podSpecOf(doc map[string]any) map[string]any {
	spec, ok := doc["spec"].(map[string]any)
	if !ok {
		return nil
	}
	if tmpl, ok := spec["template"].(map[string]any); ok {
		if ps, ok := tmpl["spec"].(map[string]any); ok {
			return ps
		}
	}
	if kind, _ := doc["kind"].(string); kind == "Pod" {
		return spec
	}
	return nil
}

func containersOf(podSpec map[string]any) []map[string]any {
	var out []map[string]any
	for _, key := range []string{"initContainers", "containers"} {
		raw, ok := podSpec[key].([]any)
		if !ok {
			continue
		}
		for _, item := range raw {
			if c, ok := item.(map[string]any); ok {
				out = append(out, c)
			}
		}
	}
	return out
}

func hasResourceRequestsLimits(container map[string]any) bool {
	res, ok := container["resources"].(map[string]any)
	if !ok {
		return false
	}
	requests, hasReq := res["requests"].(map[string]any)
	limits, hasLim := res["limits"].(map[string]any)
	return hasReq && len(requests) > 0 && hasLim && len(limits) > 0
}

func hasOwnerLabel(doc map[string]any) bool {
	labels := map[string]any{}
	if md, ok := doc["metadata"].(map[string]any); ok {
		if l, ok := md["labels"].(map[string]any); ok {
			labels = l
		}
	}
	for _, key := range []string{"app.kubernetes.io/part-of", "owner", "backstage.io/owner"} {
		if v, ok := labels[key].(string); ok && v != "" {
			return true
		}
	}
	return false
}

// imageTag extracts the tag from an image reference, ignoring digests and registry ports.
func imageTag(image string) string {
	if at := strings.Index(image, "@"); at >= 0 {
		// digest-pinned images are considered pinned; return the digest hex.
		digest := image[at+1:]
		if c := strings.LastIndex(digest, ":"); c >= 0 {
			return digest[c+1:]
		}
		return digest
	}
	lastColon := strings.LastIndex(image, ":")
	if lastColon < 0 {
		return ""
	}
	// A colon before the last slash is a registry port, not a tag.
	if slash := strings.LastIndex(image, "/"); slash > lastColon {
		return ""
	}
	return image[lastColon+1:]
}
