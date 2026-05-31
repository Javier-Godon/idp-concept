package policy

import (
	"fmt"
	"os"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

const exemptionDateLayout = "2006-01-02"

// Exemption documents a narrow, owned, time-bounded waiver for one policy rule.
type Exemption struct {
	Rule      string `yaml:"rule"`
	Kind      string `yaml:"kind,omitempty"`
	Namespace string `yaml:"namespace,omitempty"`
	Name      string `yaml:"name,omitempty"`
	Owner     string `yaml:"owner"`
	Reason    string `yaml:"reason"`
	ExpiresOn string `yaml:"expiresOn"`
}

type exemptionFile struct {
	Exemptions []Exemption `yaml:"exemptions"`
}

// LoadExemptionsFile reads a policy exemption file.
func LoadExemptionsFile(path string) ([]Exemption, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read policy exemptions %s: %w", path, err)
	}
	var file exemptionFile
	if err := yaml.Unmarshal(data, &file); err != nil {
		return nil, fmt.Errorf("parse policy exemptions %s: %w", path, err)
	}
	return file.Exemptions, nil
}

// ApplyExemptions removes findings covered by valid exemptions. Invalid,
// expired, or stale exemptions fail loudly so policy waivers stay reviewable.
func ApplyExemptions(findings []Finding, exemptions []Exemption, now time.Time) ([]Finding, error) {
	if len(exemptions) == 0 {
		return findings, nil
	}

	today := truncateUTCDate(now)
	matched := make([]bool, len(exemptions))
	for i, exemption := range exemptions {
		if err := validateExemption(exemption, today); err != nil {
			return nil, err
		}
		for _, finding := range findings {
			if exemption.matches(finding) {
				matched[i] = true
				break
			}
		}
	}

	filtered := make([]Finding, 0, len(findings))
	for _, finding := range findings {
		exempted := false
		for i, exemption := range exemptions {
			if exemption.matches(finding) {
				matched[i] = true
				exempted = true
				break
			}
		}
		if !exempted {
			filtered = append(filtered, finding)
		}
	}

	for i, ok := range matched {
		if !ok {
			return nil, fmt.Errorf("policy exemption %q for %s is stale: no current finding matches it",
				exemptions[i].Rule, exemptions[i].target())
		}
	}
	return filtered, nil
}

func validateExemption(exemption Exemption, today time.Time) error {
	var missing []string
	if exemption.Rule == "" {
		missing = append(missing, "rule")
	}
	if exemption.Owner == "" {
		missing = append(missing, "owner")
	}
	if exemption.Reason == "" {
		missing = append(missing, "reason")
	}
	if exemption.ExpiresOn == "" {
		missing = append(missing, "expiresOn")
	}
	if len(missing) > 0 {
		return fmt.Errorf("policy exemption for %s is missing required field(s): %s",
			exemption.target(), strings.Join(missing, ", "))
	}
	if exemption.Kind == "" || (exemption.Namespace == "" && exemption.Name == "") {
		return fmt.Errorf("policy exemption %q must set kind and at least one of namespace or name", exemption.Rule)
	}

	expires, err := time.Parse(exemptionDateLayout, exemption.ExpiresOn)
	if err != nil {
		return fmt.Errorf("policy exemption %q for %s has invalid expiresOn %q (expected YYYY-MM-DD)",
			exemption.Rule, exemption.target(), exemption.ExpiresOn)
	}
	if truncateUTCDate(expires).Before(today) {
		return fmt.Errorf("policy exemption %q for %s expired on %s",
			exemption.Rule, exemption.target(), exemption.ExpiresOn)
	}
	return nil
}

func (e Exemption) matches(f Finding) bool {
	if e.Rule != f.Rule {
		return false
	}
	if e.Kind != "" && e.Kind != f.Kind {
		return false
	}
	if e.Namespace != "" && e.Namespace != f.Namespace {
		return false
	}
	if e.Name != "" && e.Name != f.Name {
		return false
	}
	return true
}

func (e Exemption) target() string {
	parts := []string{}
	if e.Namespace != "" {
		parts = append(parts, "namespace="+e.Namespace)
	}
	if e.Kind != "" {
		parts = append(parts, "kind="+e.Kind)
	}
	if e.Name != "" {
		parts = append(parts, "name="+e.Name)
	}
	if len(parts) == 0 {
		return "<unspecified target>"
	}
	return strings.Join(parts, ",")
}

func truncateUTCDate(t time.Time) time.Time {
	y, m, d := t.UTC().Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}
