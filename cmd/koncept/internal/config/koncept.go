package config

import (
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

type ProjectConfig struct {
	APIVersion string          `yaml:"apiVersion"`
	Kind       string          `yaml:"kind"`
	Metadata   ProjectMetadata `yaml:"metadata"`
	Spec       ProjectSpec     `yaml:"spec"`
}

type ProjectMetadata struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
}

type ProjectSpec struct {
	FrameworkPath string           `yaml:"frameworkPath"`
	DefaultOutput string           `yaml:"defaultOutput"`
	Factory       FactoryConfig    `yaml:"factory"`
	Validation    ValidationConfig `yaml:"validation"`
	Output        OutputConfig     `yaml:"output"`
	Backstage     BackstageConfig  `yaml:"backstage"`
}

type FactoryConfig struct {
	SeedFile   string `yaml:"seedFile"`
	RenderFile string `yaml:"renderFile"`
}

type ValidationConfig struct {
	Kubeconform KubeconformConfig `yaml:"kubeconform"`
	Policy      PolicyConfig      `yaml:"policy"`
}

type KubeconformConfig struct {
	Enabled           bool     `yaml:"enabled"`
	KubernetesVersion string   `yaml:"kubernetesVersion"`
	Strict            bool     `yaml:"strict"`
	AdditionalSchemas []string `yaml:"additionalSchemas"`
}

type PolicyConfig struct {
	Enabled    bool   `yaml:"enabled"`
	Engine     string `yaml:"engine"`
	PolicyPath string `yaml:"policyPath"`
}

type OutputConfig struct {
	DefaultDir       string `yaml:"defaultDir"`
	HelmTemplatesDir string `yaml:"helmTemplatesDir"`
}

type BackstageConfig struct {
	Owner       string `yaml:"owner"`
	Lifecycle   string `yaml:"lifecycle"`
	TechdocsRef string `yaml:"techdocsRef"`
}

// Load reads koncept.yaml from the given directory or returns defaults.
func Load(dir string) *ProjectConfig {
	cfg := defaults()
	path := filepath.Join(dir, "koncept.yaml")
	data, err := os.ReadFile(path)
	if err != nil {
		return cfg
	}
	_ = yaml.Unmarshal(data, cfg)
	if cfg.Spec.Factory.SeedFile == "" {
		cfg.Spec.Factory.SeedFile = "factory_seed.k"
	}
	if cfg.Spec.Factory.RenderFile == "" {
		cfg.Spec.Factory.RenderFile = "render.k"
	}
	if cfg.Spec.DefaultOutput == "" {
		cfg.Spec.DefaultOutput = "yaml"
	}
	return cfg
}

func defaults() *ProjectConfig {
	return &ProjectConfig{
		APIVersion: "koncept.bluesolution.es/v1",
		Kind:       "ProjectConfig",
		Spec: ProjectSpec{
			DefaultOutput: "yaml",
			Factory: FactoryConfig{
				SeedFile:   "factory_seed.k",
				RenderFile: "render.k",
			},
			Output: OutputConfig{
				DefaultDir: "output",
			},
			Validation: ValidationConfig{
				Kubeconform: KubeconformConfig{
					Enabled:           true,
					KubernetesVersion: "1.31.0",
					Strict:            true,
				},
			},
		},
	}
}
