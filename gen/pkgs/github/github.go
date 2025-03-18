package github

import (
	"encoding/json"
	"fmt"
	"net/http"
)

type gitHubCommitResponse struct {
	SHA string `json:"sha"`
}

func GetFullCommitHash(owner, repo, shortHash, token string) (string, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/commits/%s", owner, repo, shortHash)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}

	// If you have a GitHub token, use it to avoid rate limits
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("got HTTP status %s for request: %s", resp.Status, url)
	}

	var commit gitHubCommitResponse
	if err := json.NewDecoder(resp.Body).Decode(&commit); err != nil {
		return "", err
	}

	return commit.SHA, nil
}
