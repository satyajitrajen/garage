// Temporary helper: boots embedded Postgres for manual server runs.
// Deleted after the run; do not commit.
package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	embeddedpostgres "github.com/fergusstrange/embedded-postgres"
)

func main() {
	pg := embeddedpostgres.NewDatabase(
		embeddedpostgres.DefaultConfig().
			Port(5433).
			Database("garage").
			RuntimePath("internal/.embedded-pg"),
	)
	fmt.Println("starting embedded postgres on :5433 ...")
	if err := pg.Start(); err != nil {
		log.Fatalf("start pg: %v", err)
	}
	fmt.Println("embedded postgres ready")
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	fmt.Println("stopping embedded postgres ...")
	if err := pg.Stop(); err != nil {
		log.Printf("stop pg: %v", err)
	}
}
