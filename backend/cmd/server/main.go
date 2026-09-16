package main

import (
	"context"
	"database/sql"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"garage-backend/internal/api"
	"garage-backend/internal/auth"
	"garage-backend/internal/config"
	"garage-backend/internal/mail"
	"garage-backend/internal/store"
	"garage-backend/migrations"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)
	cfg, err := config.Load()
	if err != nil {
		logger.Error("config load failed", "err", err)
		os.Exit(1)
	}
	// The webhook endpoint fails closed without this secret; warn loudly so
	// the misconfiguration is visible at boot instead of at first webhook.
	if cfg.RazorpayWebhookSecret == "" {
		logger.Warn("RAZORPAY_WEBHOOK_SECRET is empty: razorpay webhooks will be rejected until configured")
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Error("db pool failed", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	// Fail fast when the DB is unreachable instead of serving 500s.
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	if err := pool.Ping(pingCtx); err != nil {
		cancel()
		logger.Error("database ping failed", "err", err)
		os.Exit(1)
	}
	cancel()

	if err := migrate(cfg.DatabaseURL); err != nil {
		logger.Error("migrate failed", "err", err)
		os.Exit(1)
	}

	var sender mail.Sender = mail.LogSender{}
	if cfg.SMTPHost != "" {
		sender = mail.SMTPSender{
			Host: cfg.SMTPHost, Port: cfg.SMTPPort,
			User: cfg.SMTPUser, Pass: cfg.SMTPPass, From: cfg.SMTPFrom,
		}
	}

	handler := api.NewRouterWithOrigins(&api.Server{
		Store:  store.New(pool),
		Issuer: auth.NewTokenIssuer(cfg.JWTSecret),
		Config: cfg,
		Mail:   sender,
	}, cfg.AllowedOrigins)

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	go func() {
		logger.Info("garage server listening", "port", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("listen failed", "err", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Info("shutdown", "err", err)
	}
}

func migrate(databaseURL string) error {
	sqlDB, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return err
	}
	defer sqlDB.Close()
	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("postgres"); err != nil {
		return err
	}
	return goose.UpContext(context.Background(), sqlDB, ".")
}
