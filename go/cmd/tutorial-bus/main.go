package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	mesgd "mesgd-sdk"
	"os"
	"strings"
)

func run() error {
	if len(os.Args) != 2 || (os.Args[1] != "server" && os.Args[1] != "client") {
		return fmt.Errorf("usage: pubsub server|client")
	}
	role := os.Args[1]
	address := "client"
	if role == "server" {
		address = "service"
	}
	tlsConfig := &tls.Config{MinVersion: tls.VersionTLS12}
	if filename := os.Getenv("MESGD_CA"); filename != "" {
		pem, err := os.ReadFile(filename)
		if err != nil {
			return err
		}
		roots, err := x509.SystemCertPool()
		if err != nil {
			return err
		}
		if !roots.AppendCertsFromPEM(pem) {
			return fmt.Errorf("invalid CA file")
		}
		tlsConfig.RootCAs = roots
	}
	origin := strings.TrimRight(os.Getenv("MESGD_WSS"), "/")
	if origin == "" {
		return fmt.Errorf("set MESGD_WSS")
	}
	conn, err := mesgd.Connect(origin+"/to="+address,
		mesgd.Options{Token: os.Getenv("MESGD_TOKEN"), TLS: tlsConfig})
	if err != nil {
		return err
	}
	defer conn.Close()
	done := false
	var handlerErr error
	typ := "echo.reply"
	if role == "server" {
		typ = "echo.request"
	}
	conn.On(typ, func(message map[string]interface{}) {
		if role == "server" {
			fmt.Println("agent received:", message["body"])
			handlerErr = conn.Send(map[string]interface{}{
				"to": message["from"], "from": "service",
				"type": "echo.reply", "body": message["body"],
			}, mesgd.SendOpts{})
		} else {
			handlerErr = json.NewEncoder(os.Stdout).Encode(message["body"])
			done = true
		}
	})
	fmt.Println("ready:", role)
	if role == "client" {
		if err := conn.Send(map[string]interface{}{
			"to": "service", "from": "client", "type": "echo.request",
			"body": map[string]interface{}{"text": "hello"},
		}, mesgd.SendOpts{}); err != nil {
			return err
		}
	}
	for !done {
		if err := conn.Recv(); err != nil {
			return err
		}
		if handlerErr != nil {
			return handlerErr
		}
	}
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
