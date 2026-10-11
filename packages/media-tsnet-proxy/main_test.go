package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"tailscale.com/types/key"
)

func writeSavedIdentity(t *testing.T, directory string) {
	t.Helper()
	private := key.NewNode()
	profile, err := json.Marshal(map[string]any{"Config": map[string]any{
		"NodeID": "fixture-original-node", "PrivateNodeKey": private,
	}})
	if err != nil {
		t.Fatal(err)
	}
	state, err := json.Marshal(map[string][]byte{
		"_current-profile": []byte("fixture"), "profile-fixture": profile,
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(directory, "tailscaled.state"), state, 0600); err != nil {
		t.Fatal(err)
	}
}

func TestSavedNodeIdentityDoesNotEnrollOrReadOAuthCredentials(t *testing.T) {
	directory := t.TempDir()
	writeSavedIdentity(t, directory)
	calls := 0
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer api.Close()
	for _, legacy := range []string{"", "fixture-legacy-key"} {
		value, err := authenticationKey(context.Background(), api.Client(), api.URL, identityAuthConfig{
			StateDir: directory, LegacyKey: legacy,
			OAuthIDFile: "unavailable-fixture-id", OAuthSecretFile: "unavailable-fixture-secret",
			Tags: []string{"tag:mountainous"},
		})
		if err != nil || value != "" || calls != 0 {
			t.Fatal("saved node identity did not take precedence over enrollment credentials")
		}
	}
}

func TestInvalidExistingStateCannotTriggerEnrollment(t *testing.T) {
	fixtures := map[string][]byte{
		"malformed":      []byte(`not json`),
		"machine-only":   []byte(`{"_machinekey":"ZmFrZQ=="}`),
		"missing-config": []byte(`{"_current-profile":"Zml4dHVyZQ==","profile-fixture":"e30="}`),
	}
	for name, state := range fixtures {
		t.Run(name, func(t *testing.T) {
			directory := t.TempDir()
			if err := os.WriteFile(filepath.Join(directory, "tailscaled.state"), state, 0600); err != nil {
				t.Fatal(err)
			}
			value, err := authenticationKey(context.Background(), http.DefaultClient, "https://must-not-be-contacted.invalid", identityAuthConfig{
				StateDir: directory, LegacyKey: "fixture-legacy-key",
				OAuthIDFile: "unavailable-fixture-id", OAuthSecretFile: "unavailable-fixture-secret",
			})
			if err == nil || value != "" || !strings.Contains(err.Error(), "saved identity") {
				t.Fatal("invalid existing identity was not rejected before reading credentials or enrolling")
			}
		})
	}
}

func TestSavedIdentityRejectsForcedLoginAndStateSymlinks(t *testing.T) {
	directory := t.TempDir()
	writeSavedIdentity(t, directory)
	value, err := authenticationKey(context.Background(), http.DefaultClient, "https://must-not-be-contacted.invalid", identityAuthConfig{
		StateDir: directory, ForceLogin: true,
	})
	if err == nil || value != "" || !strings.Contains(err.Error(), "forced login") {
		t.Fatal("forced login accepted for saved identity")
	}
	linked := t.TempDir()
	if err := os.Symlink(filepath.Join(directory, "tailscaled.state"), filepath.Join(linked, "tailscaled.state")); err != nil {
		t.Fatal(err)
	}
	value, err = authenticationKey(context.Background(), http.DefaultClient, "https://must-not-be-contacted.invalid", identityAuthConfig{
		StateDir: linked, LegacyKey: "fixture-key",
	})
	if err == nil || value != "" || !strings.Contains(err.Error(), "saved identity") {
		t.Fatal("symlinked identity state accepted")
	}
}

func TestTaggedEnrollmentWithoutDeviceDeletion(t *testing.T) {
	calls := 0
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.Method != http.MethodPost {
			t.Errorf("unexpected method: %s", r.Method)
		}
		switch r.URL.Path {
		case "/oauth/token":
			r.ParseForm()
			if r.Form.Get("client_id") != "fixture-id" || r.Form.Get("client_secret") != "fixture-secret" {
				t.Error("credential delivery mismatch")
			}
			w.Write([]byte(`{"access_token":"fixture-token"}`))
		case "/tailnet/-/keys":
			if r.Header.Get("Authorization") != "Bearer fixture-token" {
				t.Error("missing authorization")
			}
			var request struct {
				Capabilities struct {
					Devices struct {
						Create struct {
							Reusable      bool     `json:"reusable"`
							Ephemeral     bool     `json:"ephemeral"`
							Preauthorized bool     `json:"preauthorized"`
							Tags          []string `json:"tags"`
						} `json:"create"`
					} `json:"devices"`
				} `json:"capabilities"`
				Expiry int `json:"expirySeconds"`
			}
			if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
				t.Fatal(err)
			}
			create := request.Capabilities.Devices.Create
			if create.Reusable || create.Ephemeral || !create.Preauthorized ||
				len(create.Tags) != 1 || create.Tags[0] != "tag:mountainous" || request.Expiry != 3600 {
				t.Error("unsafe enrollment capabilities")
			}
			w.Write([]byte(`{"key":"fixture-auth-key"}`))
		default:
			t.Errorf("unexpected API path: %s", r.URL.Path)
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer api.Close()
	directory := t.TempDir()
	idFile, secretFile := filepath.Join(directory, "id"), filepath.Join(directory, "secret")
	if err := os.WriteFile(idFile, []byte("fixture-id"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(secretFile, []byte("fixture-secret"), 0600); err != nil {
		t.Fatal(err)
	}
	key, err := authenticationKey(context.Background(), api.Client(), api.URL, identityAuthConfig{
		StateDir: directory, OAuthIDFile: idFile, OAuthSecretFile: secretFile,
		Tags: []string{"tag:mountainous"},
	})
	if err != nil || key != "fixture-auth-key" || calls != 2 {
		t.Fatal("enrollment contract failed")
	}
}

func TestEnrollmentFailureDoesNotDiscloseCredentialsOrServerBody(t *testing.T) {
	for _, status := range []int{http.StatusUnauthorized, http.StatusOK} {
		api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(status)
			w.Write([]byte(`fixture-secret fixture-token https://private-login.invalid/`))
		}))
		_, err := enrollmentKey(context.Background(), api.Client(), api.URL,
			"fixture-id", "fixture-secret", []string{"tag:mountainous"})
		api.Close()
		if err == nil {
			t.Fatal("invalid enrollment response accepted")
		}
		for _, private := range []string{"fixture-secret", "fixture-token", "private-login"} {
			if strings.Contains(err.Error(), private) {
				t.Fatal("private detail in error")
			}
		}
	}
}

func TestReverseProxyKeepsPathAndReplacesForwardingHeaders(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/status" {
			t.Error("request path changed")
		}
		if strings.Contains(r.Header.Get("X-Forwarded-For"), "untrusted") {
			t.Error("caller IP trusted")
		}
		if r.Header.Get("X-Forwarded-Host") != "service.example" ||
			r.Header.Get("X-Forwarded-Proto") != "https" {
			t.Error("forwarded origin mismatch")
		}
		w.Write([]byte("ok"))
	}))
	defer backend.Close()
	backendURL, _ := url.Parse(backend.URL)
	request := httptest.NewRequest(http.MethodGet, "http://service.example/api/status", nil)
	request.Header.Set("X-Forwarded-For", "untrusted")
	response := httptest.NewRecorder()
	proxyHandler(backendURL).ServeHTTP(response, request)
	if response.Code != http.StatusOK || response.Body.String() != "ok" {
		t.Fatal("proxy contract failed")
	}
}
