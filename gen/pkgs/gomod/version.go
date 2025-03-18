package gomod

import (
	"fmt"
	"regexp"
)

type GoModVersion struct {
	Version      string
	Timestamp    string
	GitShortHash string
}

func (g GoModVersion) String() string {
	if g.IsPseudo() {
		return fmt.Sprintf("v%s-0.%s-%s", g.Version, g.Timestamp, g.GitShortHash)
	}
	return fmt.Sprintf("v%s", g.Version)
}

func (g GoModVersion) IsPseudo() bool {
	return g.Timestamp != "" && g.GitShortHash != ""
}

func ParseGoModVersion(str string) (GoModVersion, error) {
	gmv := GoModVersion{}
	// Regular expression to match the version with optional timestamp and git hash
	re := regexp.MustCompile(`^v(\d+\.\d+\.\d+)(?:(?:-pre\.)?-0\.(\d{14})-([a-f0-9]{12}))?$`)

	matches := re.FindStringSubmatch(str)
	if matches == nil {
		return gmv, fmt.Errorf("version %q does not match expected format", str)
	}

	gmv.Version = matches[1]
	if len(matches) > 2 {
		gmv.Timestamp = matches[2]
		gmv.GitShortHash = matches[3]
	}

	return gmv, nil
}
