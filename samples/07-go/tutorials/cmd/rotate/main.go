package main

import (
	"context"
	deskcite "deskcite-sdk"
	"deskcite-sdk/samples/tutorials/internal/tutorial"
	"errors"
	"fmt"
	"os"
)

func run() error {
	if os.Getenv("DESKCITE_TOKEN_FILE") == "" {
		return fmt.Errorf("set DESKCITE_TOKEN_FILE before rotation")
	}
	c, old, e := tutorial.Load()
	if e != nil {
		return e
	}
	ctx := context.Background()
	r, e := c.Refresh(ctx)
	if e != nil {
		return e
	}
	var b struct {
		AccessToken string `json:"access_token"`
	}
	if e = r.JSON(&b); e != nil {
		return e
	}
	if b.AccessToken == "" {
		return fmt.Errorf("missing replacement")
	}
	if e = tutorial.Store(b.AccessToken); e != nil {
		return e
	}
	if e = c.SetToken(b.AccessToken); e != nil {
		return e
	}
	if _, e = c.Status(ctx); e != nil {
		return e
	}
	if e = c.SetToken(old); e != nil {
		return e
	}
	_, e = c.Status(ctx)
	var httpError *deskcite.HTTPError
	if !errors.As(e, &httpError) || httpError.Response.Status != 401 {
		return fmt.Errorf("old bearer was not rejected with 401")
	}
	if e = c.SetToken(b.AccessToken); e != nil {
		return e
	}
	fmt.Println("Credential rotated and saved; replacement works; old bearer rejected.")
	return nil
}
func main() {
	if e := run(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
