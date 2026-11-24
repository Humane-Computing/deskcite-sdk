package deskcite

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	mesgd "mesgd-sdk"
	"net/http"
	"os"
	"strings"
	"testing"
)

func TestInput(t *testing.T) {
	for _, origin := range []string{"http://example.test", "https://u@example.test", "https://example.test/path"} {
		if _, err := New(origin, "token", nil); err == nil {
			t.Fatal(origin)
		}
	}
	for _, path := range []string{"https://elsewhere.test/x", "/deskcite/documents/%2e%2e/x", "/deskcite/documents/a?x=1"} {
		if _, err := documentPath(path); err == nil {
			t.Fatal(path)
		}
	}
}
func TestLive(t *testing.T) {
	origin := os.Getenv("DS_TEST_URL")
	if origin == "" {
		t.Skip("run tests/integration.mjs for isolated HTTPS/WSS checks")
	}
	ca, err := os.ReadFile(os.Getenv("DS_TEST_CA"))
	if err != nil {
		t.Fatal(err)
	}
	roots := x509.NewCertPool()
	if !roots.AppendCertsFromPEM(ca) {
		t.Fatal("invalid CA")
	}
	tlsConfig := &tls.Config{RootCAs: roots, MinVersion: tls.VersionTLS12}
	c, err := New(origin, "test-bearer", &http.Transport{TLSClientConfig: tlsConfig})
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	for name, spec := range operations {
		if name == "refresh" || name == "question" || name == "document" {
			continue
		}
		var args map[string]any
		if spec.Kind == "json" {
			args = map[string]any{"text": "café & ?", "q": "test", "action": "calendar"}
		}
		r, err := c.Call(ctx, name, args)
		if err != nil {
			t.Fatal(name, err)
		}
		var body map[string]any
		if r.JSON(&body) != nil || body["ok"] != true {
			t.Fatal(name, string(r.Body))
		}
	}
	r, err := c.Question(ctx, "id/ ?#")
	if err != nil {
		t.Fatal(err)
	}
	var body map[string]any
	r.JSON(&body)
	if !strings.HasSuffix(body["path"].(string), "id%2F%20%3F%23") {
		t.Fatal(body)
	}
	r, err = c.Document(ctx, "/deskcite/documents/a%20b.pdf")
	if err != nil || string(r.Body) != string([]byte{0, 255, 10}) {
		t.Fatal("document", err)
	}
	for text, status := range map[string]int{"__error__": 503, "__redirect__": 302} {
		_, err := c.Similar(ctx, map[string]any{"text": text})
		var httpErr *HTTPError
		if !errors.As(err, &httpErr) || httpErr.Response.Status != status || len(httpErr.Response.Body) == 0 {
			t.Fatal(err)
		}
	}
	r, err = c.Refresh(ctx)
	if err != nil {
		t.Fatal(err)
	}
	var renewed struct {
		AccessToken string `json:"access_token"`
	}
	json.Unmarshal(r.Body, &renewed)
	if err = c.SetToken(renewed.AccessToken); err != nil {
		t.Fatal(err)
	}
	r, err = c.Status(ctx)
	if err != nil {
		t.Fatal(err)
	}
	r.JSON(&body)
	if body["credential"] != "rotated" {
		t.Fatal(body)
	}
	var event map[string]interface{}
	conn, err := c.Events(func(m map[string]interface{}) { event = m }, mesgd.Options{TLS: tlsConfig})
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	if err = conn.Recv(); err != nil {
		t.Fatal(err)
	}
	if event["type"] != "import.done" {
		t.Fatal(event)
	}
}
