package main

import (
	"context"
	"deskcite-sdk/internal/tutorial"
	"fmt"
	"os"
)

func run() error {
	c, _, e := tutorial.Load()
	if e != nil {
		return e
	}
	r, e := c.Similar(context.Background(), map[string]any{"text": "How do I upload a document in Deskcite?", "n": 3})
	if e != nil {
		return e
	}
	var body struct {
		Rows []struct {
			Answer string
			Path   string
		}
	}
	if e = r.JSON(&body); e != nil {
		return e
	}
	for _, row := range body.Rows {
		fmt.Println(row.Answer)
		fmt.Println("Source:", row.Path)
	}
	return nil
}
func main() {
	if e := run(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
