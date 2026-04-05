package main

import (
	"os"

	"github.com/idp-concept/koncept/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
