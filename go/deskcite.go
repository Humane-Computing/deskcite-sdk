// Package deskcite exposes the Deskcite product API and mesgd events.
package deskcite

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	mesgd "mesgd-sdk"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

//go:embed operations.json
var contract []byte

type operation struct {
	Method string
	Path   string
	Kind   string
}

var operations = func() map[string]operation {
	var ops map[string]operation
	if err := json.Unmarshal(contract, &ops); err != nil {
		panic(err)
	}
	return ops
}()

type Response struct {
	Status  int
	Headers http.Header
	Body    []byte
}

func (r *Response) JSON(value any) error { return json.Unmarshal(r.Body, value) }

type HTTPError struct{ Response *Response }

func (e *HTTPError) Error() string { return fmt.Sprintf("Deskcite HTTP %d", e.Response.Status) }

type Client struct {
	origin string
	token  string
	mu     sync.RWMutex
	http   *http.Client
}

func New(origin, token string, transport http.RoundTripper) (*Client, error) {
	u, err := url.Parse(origin)
	if err != nil || u.Scheme != "https" || u.Hostname() == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || (u.Path != "" && u.Path != "/") {
		return nil, fmt.Errorf("expected an HTTPS origin")
	}
	c := &Client{origin: strings.TrimSuffix(origin, "/"), http: &http.Client{
		Transport: transport, Timeout: 30 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}}
	if err := c.SetToken(token); err != nil {
		return nil, err
	}
	return c, nil
}
func (c *Client) SetToken(token string) error {
	if token == "" {
		return fmt.Errorf("expected bearer token")
	}
	for _, b := range []byte(token) {
		if b < 33 || b > 126 {
			return fmt.Errorf("invalid bearer token")
		}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.token = token
	return nil
}
func (c *Client) bearer() string { c.mu.RLock(); defer c.mu.RUnlock(); return c.token }
func documentPath(p string) (string, error) {
	decoded, err := url.PathUnescape(p)
	if err != nil || !strings.HasPrefix(p, "/deskcite/documents/") || strings.ContainsAny(p, "?#\\") {
		return "", fmt.Errorf("invalid document path")
	}
	for _, b := range []byte(p) {
		if b <= 32 || b == 127 {
			return "", fmt.Errorf("invalid document path")
		}
	}
	for _, b := range []byte(decoded) {
		if b < 32 || b == 127 || b == '\\' {
			return "", fmt.Errorf("invalid document path")
		}
	}
	for _, segment := range strings.Split(decoded, "/") {
		if segment == "." || segment == ".." {
			return "", fmt.Errorf("invalid document path")
		}
	}
	return p, nil
}
func (c *Client) Call(ctx context.Context, name string, args map[string]any) (*Response, error) {
	spec, ok := operations[name]
	if !ok {
		return nil, fmt.Errorf("unknown operation: %s", name)
	}
	path := spec.Path
	if spec.Kind == "id" {
		id, ok := args["id"].(string)
		if !ok || id == "" {
			return nil, fmt.Errorf("expected id")
		}
		path += url.PathEscape(id)
	}
	if spec.Kind == "document" {
		p, ok := args["path"].(string)
		if !ok {
			return nil, fmt.Errorf("expected document path")
		}
		var err error
		path, err = documentPath(p)
		if err != nil {
			return nil, err
		}
	}
	var body io.Reader
	if spec.Kind == "json" {
		if args == nil {
			args = map[string]any{}
		}
		data, err := json.Marshal(args)
		if err != nil {
			return nil, err
		}
		body = bytes.NewReader(data)
	}
	if spec.Kind == "none" && len(args) != 0 {
		return nil, fmt.Errorf("operation takes no arguments")
	}
	req, err := http.NewRequestWithContext(ctx, spec.Method, c.origin+path, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.bearer())
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	r, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()
	data, err := io.ReadAll(r.Body)
	if err != nil {
		return nil, err
	}
	response := &Response{r.StatusCode, r.Header, data}
	if r.StatusCode < 200 || r.StatusCode >= 300 {
		return response, &HTTPError{response}
	}
	return response, nil
}
func (c *Client) Question(ctx context.Context, id string) (*Response, error) {
	return c.Call(ctx, "question", map[string]any{"id": id})
}
func (c *Client) Document(ctx context.Context, path string) (*Response, error) {
	return c.Call(ctx, "document", map[string]any{"path": path})
}

// Events returns the underlying mesgd connection. Call Recv in the host's
// receive loop, and Close before replacing credentials and reconnecting.
func (c *Client) Events(handler func(map[string]interface{}), options mesgd.Options) (*mesgd.Conn, error) {
	options.Token = c.bearer()
	conn, err := mesgd.Connect("wss://"+strings.TrimPrefix(c.origin, "https://")+"/deskcite/events", options)
	if err != nil {
		return nil, err
	}
	conn.On("*", handler)
	return conn, nil
}
