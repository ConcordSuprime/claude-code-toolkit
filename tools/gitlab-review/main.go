package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
)

const maxDiffLines = 150

// --- GitLab API client ---

type client struct {
	host  string
	token string
}

func newClient() (*client, error) {
	host := os.Getenv("GITLAB_HOST")
	if host == "" {
		host = "https://oes-gitlab.oeswork.io"
	}
	token := os.Getenv("GITLAB_TOKEN")
	if token == "" {
		return nil, fmt.Errorf("GITLAB_TOKEN is not set")
	}
	return &client{host: strings.TrimRight(host, "/"), token: token}, nil
}

func (c *client) get(path string, out any) error {
	req, err := http.NewRequest(http.MethodGet, c.host+"/api/v4/"+path, nil)
	if err != nil {
		return err
	}
	req.Header.Set("PRIVATE-TOKEN", c.token)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API %s: %d %s", path, resp.StatusCode, body)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

func (c *client) getRaw(path string) string {
	req, err := http.NewRequest(http.MethodGet, c.host+"/api/v4/"+path, nil)
	if err != nil {
		return "(not found)"
	}
	req.Header.Set("PRIVATE-TOKEN", c.token)

	resp, err := http.DefaultClient.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		return "(not found)"
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	return string(body)
}

// --- URL parsing ---

type parsedURL struct {
	projectPath string
	mrIID       string
	commitSHA   string
}

func parseURL(raw string) (*parsedURL, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("invalid URL: %w", err)
	}

	re := regexp.MustCompile(`^/(.+?)/-/merge_requests/(\d+)`)
	m := re.FindStringSubmatch(u.Path)
	if m == nil {
		return nil, fmt.Errorf("expected URL like .../merge_requests/N, got: %s", raw)
	}

	return &parsedURL{
		projectPath: m[1],
		mrIID:       m[2],
		commitSHA:   u.Query().Get("commit_id"),
	}, nil
}

// --- GitLab data types ---

type mrInfo struct {
	Title        string `json:"title"`
	Description  string `json:"description"`
	SourceBranch string `json:"source_branch"`
	TargetBranch string `json:"target_branch"`
	Author       struct {
		Name string `json:"name"`
	} `json:"author"`
}

type mrChanges struct {
	Changes []diffEntry `json:"changes"`
}

type commitInfo struct {
	Title        string `json:"title"`
	Message      string `json:"message"`
	AuthorName   string `json:"author_name"`
	AuthoredDate string `json:"authored_date"`
	Stats        struct {
		Additions int `json:"additions"`
		Deletions int `json:"deletions"`
	} `json:"stats"`
}

type diffEntry struct {
	OldPath string `json:"old_path"`
	NewPath string `json:"new_path"`
	Diff    string `json:"diff"`
}

func (d diffEntry) path() string {
	if d.NewPath != "" {
		return d.NewPath
	}
	return d.OldPath
}

// --- Formatting ---

func printDiffs(diffs []diffEntry) {
	for _, d := range diffs {
		if strings.TrimSpace(d.Diff) == "" {
			continue
		}
		lines := strings.Split(d.Diff, "\n")
		diff := d.Diff
		if len(lines) > maxDiffLines {
			diff = strings.Join(lines[:maxDiffLines], "\n")
			fmt.Printf("\n### %s\n```diff\n%s\n... (%d more lines truncated)\n```\n", d.path(), diff, len(lines)-maxDiffLines)
			continue
		}
		fmt.Printf("\n### %s\n```diff\n%s\n```\n", d.path(), diff)
	}
}

func printGoMod(gomod string) {
	fmt.Println("## go.mod (project dependencies)")
	fmt.Println("```")
	fmt.Println(strings.TrimSpace(gomod))
	fmt.Println("```")
	fmt.Println()
}


// --- MR mode ---

func reviewMR(c *client, p *parsedURL, rawURL string) error {
	enc := url.PathEscape(p.projectPath)
	api := fmt.Sprintf("projects/%s", enc)

	var mr mrInfo
	if err := c.get(api+"/merge_requests/"+p.mrIID, &mr); err != nil {
		return fmt.Errorf("fetch MR: %w", err)
	}

	var changes mrChanges
	if err := c.get(api+"/merge_requests/"+p.mrIID+"/changes", &changes); err != nil {
		return fmt.Errorf("fetch changes: %w", err)
	}

	ref := url.QueryEscape(mr.TargetBranch)
	gomod := c.getRaw(api + "/repository/files/go.mod/raw?ref=" + ref)

	desc := strings.TrimSpace(mr.Description)
	if desc == "" {
		desc = "(no description)"
	}

	fmt.Println("# MR Review Context")
	fmt.Println()
	fmt.Println("## Merge Request")
	fmt.Printf("- **Title:** %s\n", mr.Title)
	fmt.Printf("- **Author:** %s\n", mr.Author.Name)
	fmt.Printf("- **Branch:** `%s` → `%s`\n", mr.SourceBranch, mr.TargetBranch)
	fmt.Printf("- **Changed files:** %d\n", len(changes.Changes))
	fmt.Printf("- **URL:** %s\n\n", rawURL)
	fmt.Printf("## Description\n%s\n\n", desc)
	printGoMod(gomod)
	fmt.Println("## Code Changes")
	printDiffs(changes.Changes)

	return nil
}

// --- Commit mode ---

func reviewCommit(c *client, p *parsedURL, rawURL string) error {
	enc := url.PathEscape(p.projectPath)
	api := fmt.Sprintf("projects/%s", enc)

	var commit commitInfo
	if err := c.get(api+"/repository/commits/"+p.commitSHA, &commit); err != nil {
		return fmt.Errorf("fetch commit: %w", err)
	}

	var diffs []diffEntry
	if err := c.get(api+"/repository/commits/"+p.commitSHA+"/diff?per_page=50", &diffs); err != nil {
		return fmt.Errorf("fetch diff: %w", err)
	}

	// Get target branch from MR for go.mod
	targetBranch := "main"
	if p.mrIID != "" {
		var mr mrInfo
		if err := c.get(api+"/merge_requests/"+p.mrIID, &mr); err == nil {
			targetBranch = mr.TargetBranch
		}
	}
	ref := url.QueryEscape(targetBranch)
	gomod := c.getRaw(api + "/repository/files/go.mod/raw?ref=" + ref)

	sha := p.commitSHA
	if len(sha) > 12 {
		sha = sha[:12]
	}

	fmt.Println("# Code Review Context")
	fmt.Println()
	fmt.Println("## Commit")
	fmt.Printf("- **SHA:** `%s`\n", sha)
	fmt.Printf("- **Title:** %s\n", commit.Title)
	fmt.Printf("- **Author:** %s\n", commit.AuthorName)
	fmt.Printf("- **Date:** %s\n", commit.AuthoredDate)
	fmt.Printf("- **Changes:** +%d / -%d in %d files\n", commit.Stats.Additions, commit.Stats.Deletions, len(diffs))
	fmt.Printf("- **URL:** %s\n\n", rawURL)
	printGoMod(gomod)
	fmt.Println("## Code Changes")
	printDiffs(diffs)

	return nil
}

// --- Entry point ---

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: gitlab-review <MR_URL or commit URL>")
		os.Exit(1)
	}

	c, err := newClient()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}

	rawURL := os.Args[1]
	p, err := parseURL(rawURL)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}

	if p.commitSHA != "" {
		err = reviewCommit(c, p, rawURL)
	} else {
		err = reviewMR(c, p, rawURL)
	}

	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
}
