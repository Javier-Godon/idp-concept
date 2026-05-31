package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/idp-concept/koncept/internal/changelog"
	"github.com/spf13/cobra"
)

var (
	changelogDir     string
	changelogType    string
	changelogSummary string
	changelogOwner   string
	changelogIssue   string
	changelogDetails string
	changelogVersion string
	changelogFile    string
)

var changelogCmd = &cobra.Command{
	Use:   "changelog",
	Short: "Manage release-note fragments for platform changes",
	Long: `changelog manages small YAML fragments under .changes/unreleased/.

Fragments are reviewed with code changes and rendered into Keep-a-Changelog
Markdown during a framework/platform release.`,
}

var changelogNewCmd = &cobra.Command{
	Use:   "new <slug>",
	Short: "Create a changelog fragment",
	Args:  cobra.ExactArgs(1),
	RunE:  runChangelogNew,
}

var changelogCheckCmd = &cobra.Command{
	Use:   "check",
	Short: "Validate changelog fragments",
	RunE:  runChangelogCheck,
}

var changelogRenderCmd = &cobra.Command{
	Use:   "render",
	Short: "Render changelog fragments to Markdown",
	RunE:  runChangelogRender,
}

func runChangelogNew(cmd *cobra.Command, args []string) error {
	slug := normalizeChangelogSlug(args[0])
	if slug == "" {
		return fmt.Errorf("slug must contain at least one letter or number")
	}
	fragment := changelog.Fragment{
		Type:    changelogType,
		Summary: changelogSummary,
		Owner:   changelogOwner,
		Issue:   changelogIssue,
		Details: changelogDetails,
	}
	path := filepath.Join(changelogDir, slug+".yaml")
	if err := changelog.WriteFragment(path, fragment); err != nil {
		return err
	}
	printSuccess(fmt.Sprintf("Changelog fragment created: %s", path))
	return nil
}

func runChangelogCheck(cmd *cobra.Command, args []string) error {
	fragments, err := changelog.ReadDir(changelogDir)
	if err != nil {
		return err
	}
	printSuccess(fmt.Sprintf("changelog: %d fragment(s) valid in %s", len(fragments), changelogDir))
	return nil
}

func runChangelogRender(cmd *cobra.Command, args []string) error {
	fragments, err := changelog.ReadDir(changelogDir)
	if err != nil {
		return err
	}
	out, err := changelog.RenderMarkdown(changelogVersion, time.Now(), fragments)
	if err != nil {
		return err
	}
	if changelogFile == "" {
		fmt.Print(out)
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(changelogFile), 0o755); err != nil && filepath.Dir(changelogFile) != "." {
		return fmt.Errorf("create changelog output dir: %w", err)
	}
	if err := os.WriteFile(changelogFile, []byte(out), 0o644); err != nil {
		return fmt.Errorf("write changelog output %s: %w", changelogFile, err)
	}
	printSuccess(fmt.Sprintf("Changelog written to %s", changelogFile))
	return nil
}

var changelogSlugRE = regexp.MustCompile(`[^a-z0-9]+`)

func normalizeChangelogSlug(slug string) string {
	slug = strings.ToLower(strings.TrimSpace(slug))
	slug = changelogSlugRE.ReplaceAllString(slug, "-")
	return strings.Trim(slug, "-")
}

func init() {
	changelogCmd.PersistentFlags().StringVar(&changelogDir, "dir", ".changes/unreleased", "directory containing unreleased changelog fragments")

	changelogNewCmd.Flags().StringVar(&changelogType, "type", "changed", "fragment type: added|changed|deprecated|removed|fixed|security|known-issue")
	changelogNewCmd.Flags().StringVar(&changelogSummary, "summary", "", "short release-note summary")
	changelogNewCmd.Flags().StringVar(&changelogOwner, "owner", "", "accountable team or person")
	changelogNewCmd.Flags().StringVar(&changelogIssue, "issue", "", "optional issue, ticket, or PR reference")
	changelogNewCmd.Flags().StringVar(&changelogDetails, "details", "", "optional extra detail")
	_ = changelogNewCmd.MarkFlagRequired("summary")
	_ = changelogNewCmd.MarkFlagRequired("owner")

	changelogRenderCmd.Flags().StringVar(&changelogVersion, "version", "", "release version for the rendered changelog section")
	changelogRenderCmd.Flags().StringVar(&changelogFile, "file", "", "optional Markdown output file; stdout when omitted")
	_ = changelogRenderCmd.MarkFlagRequired("version")

	changelogCmd.AddCommand(changelogNewCmd)
	changelogCmd.AddCommand(changelogCheckCmd)
	changelogCmd.AddCommand(changelogRenderCmd)
}
