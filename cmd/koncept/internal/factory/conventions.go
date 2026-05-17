package factory

import (
	"bufio"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type ConventionContext struct {
	ProjectSlug    string
	ProjectRoot    string
	ProjectVersion string
	ReleaseKind    string
	ReleaseID      string
	Environment    string
	Version        string
	ReleaseName    string
	ManifestPath   string
}

var versionPrefixRE = regexp.MustCompile(`^v([0-9]+(?:_[0-9]+)*)(?:_|$)`)

// DeriveConventionContext extracts standard values from supported folder layouts:
//
//	projects/<project>/pre_releases/manifests/<env>/factory
//	projects/<project>/releases/<release_id>/factory
func DeriveConventionContext(factoryDir string) ConventionContext {
	absFactory, err := filepath.Abs(factoryDir)
	if err != nil {
		absFactory = factoryDir
	}
	absFactory = filepath.Clean(absFactory)

	parts := splitPath(absFactory)
	ctx := ConventionContext{}

	projectIdx := indexOf(parts, "projects")
	if projectIdx >= 0 && projectIdx+1 < len(parts) {
		ctx.ProjectSlug = parts[projectIdx+1]
		ctx.ProjectRoot = joinAbsolute(parts[:projectIdx+2])
	}

	if ctx.ProjectRoot != "" {
		ctx.ProjectVersion = readKCLModVersion(ctx.ProjectRoot)
	}

	releaseIdx := indexOf(parts, "pre_releases")
	if releaseIdx >= 0 {
		ctx.ReleaseKind = "pre_release"
		if releaseIdx+2 < len(parts) && parts[releaseIdx+1] == "manifests" {
			ctx.Environment = parts[releaseIdx+2]
			ctx.ReleaseID = ctx.Environment
		}
		if ctx.Environment != "" {
			ctx.ReleaseName = "pre_release_" + ctx.Environment
			if ctx.ProjectVersion != "" {
				ctx.Version = ctx.ProjectVersion + "-" + ctx.Environment
			}
		}
	} else if releaseIdx = indexOf(parts, "releases"); releaseIdx >= 0 {
		ctx.ReleaseKind = "release"
		if releaseIdx+1 < len(parts) {
			ctx.ReleaseID = parts[releaseIdx+1]
			ctx.ReleaseName = "release_" + ctx.ReleaseID
			ctx.Version = versionFromReleaseID(ctx.ReleaseID)
			ctx.Environment = environmentFromReleaseID(ctx.ReleaseID)
		}
	}

	ctx.ManifestPath = deriveManifestPath(absFactory)
	return ctx
}

// ConventionOptions converts derived folder context into KCL -D option values.
func ConventionOptions(factoryDir string) []string {
	ctx := DeriveConventionContext(factoryDir)
	options := []string{}
	add := func(key, value string) {
		if value != "" {
			options = append(options, key+"="+value)
		}
	}

	add("koncept_project_slug", ctx.ProjectSlug)
	add("koncept_project_version", ctx.ProjectVersion)
	add("koncept_release_kind", ctx.ReleaseKind)
	add("koncept_release_id", ctx.ReleaseID)
	add("koncept_environment", ctx.Environment)
	add("koncept_version", ctx.Version)
	add("koncept_release_name", ctx.ReleaseName)
	add("koncept_manifest_path", ctx.ManifestPath)
	return options
}

func splitPath(path string) []string {
	volume := filepath.VolumeName(path)
	trimmed := strings.TrimPrefix(path, volume)
	trimmed = strings.Trim(trimmed, string(filepath.Separator))
	if trimmed == "" {
		return []string{}
	}
	return strings.Split(trimmed, string(filepath.Separator))
}

func indexOf(parts []string, value string) int {
	for i, part := range parts {
		if part == value {
			return i
		}
	}
	return -1
}

func joinAbsolute(parts []string) string {
	if len(parts) == 0 {
		return string(filepath.Separator)
	}
	return filepath.Join(string(filepath.Separator), filepath.Join(parts...))
}

func readKCLModVersion(projectRoot string) string {
	file, err := os.Open(filepath.Join(projectRoot, "kcl.mod"))
	if err != nil {
		return ""
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "version") {
			parts := strings.SplitN(line, "=", 2)
			if len(parts) != 2 {
				continue
			}
			return strings.Trim(strings.TrimSpace(parts[1]), `"'`)
		}
	}
	return ""
}

func versionFromReleaseID(releaseID string) string {
	match := versionPrefixRE.FindStringSubmatch(releaseID)
	if len(match) < 2 {
		return ""
	}
	return strings.ReplaceAll(match[1], "_", ".")
}

func environmentFromReleaseID(releaseID string) string {
	match := versionPrefixRE.FindStringSubmatchIndex(releaseID)
	if len(match) == 0 || match[1] >= len(releaseID) {
		return ""
	}
	env := strings.TrimPrefix(releaseID[match[1]:], "_")
	return strings.Trim(env, "_")
}

func deriveManifestPath(absFactory string) string {
	outputPath := filepath.Join(filepath.Dir(absFactory), "output")
	parts := splitPath(outputPath)
	projectIdx := indexOf(parts, "projects")
	if projectIdx >= 0 {
		return filepath.ToSlash(filepath.Join(parts[projectIdx:]...))
	}
	return filepath.ToSlash(outputPath)
}
