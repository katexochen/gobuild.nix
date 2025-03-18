package gomod

import (
	"testing"
)

func TestParse(t *testing.T) {
	tests := []struct {
		input                string
		expectedVersion      string
		expectedTimestamp    string
		expectedGitShortHash string
		expectError          bool
	}{
		// Valid cases
		{"v1.2.3", "1.2.3", "", "", false},
		{"v1.2.3-0.20230425103015-deadbeef1234", "1.2.3", "20230425103015", "deadbeef1234", false},
		{"v1.2.3-pre.0.20230425103015-deadbeef1234", "1.2.3", "20230425103015", "deadbeef1234", false},
		// invalid according to https://go.dev/ref/mod#pseudo-versions, but still seen in the wild
		{"v1.2.3-20230425103015-deadbeef1234", "1.2.3", "20230425103015", "deadbeef1234", false},

		// Invalid cases
		{"something", "", "", "", true},
	}

	for _, test := range tests {
		goModVersion, err := ParseGoModVersion(test.input)

		if test.expectError {
			if err == nil {
				t.Errorf("Expected error for input %q, but got none", test.input)
			}
		} else {
			if err != nil {
				t.Errorf("Did not expect error for input %q, but got: %v", test.input, err)
			}
			if goModVersion.Version != test.expectedVersion {
				t.Errorf("For input %q, expected version %q, but got %q", test.input, test.expectedVersion, goModVersion.Version)
			}
			if goModVersion.Timestamp != test.expectedTimestamp {
				t.Errorf("For input %q, expected timestamp %q, but got %q", test.input, test.expectedTimestamp, goModVersion.Timestamp)
			}
			if goModVersion.GitShortHash != test.expectedGitShortHash {
				t.Errorf("For input %q, expected short hash %q, but got %q", test.input, test.expectedGitShortHash, goModVersion.GitShortHash)
			}
		}
	}
}
