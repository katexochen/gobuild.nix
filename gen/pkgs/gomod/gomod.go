package gomod

import (
	"fmt"
	"net/http"
	"strings"

	"golang.org/x/net/html"
)

type GoImportMeta struct {
	Prefix  string
	VCS     string
	RepoURL string
}

func FetchGoImportMeta(module string) (*GoImportMeta, error) {
	url := "https://" + module + "?go-get=1"
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch module info: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected HTTP status: %d", resp.StatusCode)
	}

	// Parse HTML and extract <meta> tag with go-import
	tokenizer := html.NewTokenizer(resp.Body)
	for {
		tt := tokenizer.Next()
		switch tt {
		case html.ErrorToken:
			return nil, fmt.Errorf("failed to find go-import meta tag")
		case html.StartTagToken, html.SelfClosingTagToken:
			token := tokenizer.Token()
			if token.Data == "meta" {
				var name, content string
				for _, attr := range token.Attr {
					if attr.Key == "name" && attr.Val == "go-import" {
						name = attr.Val
					}
					if attr.Key == "content" {
						content = attr.Val
					}
				}
				if name == "go-import" {
					// The content should be in the format: "prefix vcs repoURL"
					parts := strings.Fields(content)
					if len(parts) == 3 {
						return &GoImportMeta{
							Prefix:  parts[0],
							VCS:     parts[1],
							RepoURL: parts[2],
						}, nil
					}
				}
			}
		}
	}
}
