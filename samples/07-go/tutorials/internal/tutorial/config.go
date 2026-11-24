package tutorial

import (
	"crypto/tls"
	"crypto/x509"
	deskcite "deskcite-sdk"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func Load() (*deskcite.Client, string, error) {
	token := os.Getenv("DESKCITE_TOKEN")
	if path := os.Getenv("DESKCITE_TOKEN_FILE"); path != "" {
		b, e := os.ReadFile(path)
		if e != nil {
			return nil, "", e
		}
		token = strings.TrimSpace(string(b))
	}
	roots, e := x509.SystemCertPool()
	if e != nil {
		return nil, "", e
	}
	if ca := os.Getenv("DESKCITE_CA"); ca != "" {
		b, e := os.ReadFile(ca)
		if e != nil {
			return nil, "", e
		}
		if !roots.AppendCertsFromPEM(b) {
			return nil, "", fmt.Errorf("invalid CA")
		}
	}
	c, e := deskcite.New(os.Getenv("DESKCITE_URL"), token, &http.Transport{TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS12, RootCAs: roots}})
	return c, token, e
}
func Store(token string) error {
	target := os.Getenv("DESKCITE_TOKEN_FILE")
	if target == "" {
		return fmt.Errorf("set DESKCITE_TOKEN_FILE")
	}
	f, e := os.CreateTemp(filepath.Dir(target), ".rotate-")
	if e != nil {
		return e
	}
	defer os.Remove(f.Name())
	if _, e = f.WriteString(token + "\n"); e != nil {
		f.Close()
		return e
	}
	if e = f.Sync(); e != nil {
		f.Close()
		return e
	}
	if e = f.Close(); e != nil {
		return e
	}
	return os.Rename(f.Name(), target)
}
