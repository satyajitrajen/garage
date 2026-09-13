// Package migrations embeds the SQL migration files so the server binary can
// run goose itself on boot with no external files.
package migrations

import "embed"

//go:embed *.sql
var FS embed.FS
