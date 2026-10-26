package config

import (
	"errors"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	Port           string
	DatabaseURL    string
	JWTSecret      string
	AllowedOrigins []string

	AppBaseURL            string
	TrialDays             int
	SuperadminEmails      []string
	SMTPHost              string
	SMTPPort              int
	SMTPUser              string
	SMTPPass              string
	SMTPFrom              string
	RazorpayKeyID         string
	RazorpayKeySecret     string
	RazorpayWebhookSecret string
	RazorpayPlanMonthly   string
	RazorpayPlanYearly    string
	// PlanPriceMonthly / PlanPriceYearly are display prices in rupees shown
	// on the subscription screen; 0 hides the price.
	PlanPriceMonthly int
	PlanPriceYearly  int
	// SiteDir holds the built public website (index.html + assets) served
	// for every path outside /api; empty serves the API only.
	SiteDir string
	// RazorpayAPIBase defaults to https://api.razorpay.com; tests point it at
	// a fake server.
	RazorpayAPIBase string

	// Apple in-app purchase (iOS). The App Store Server API key comes from
	// App Store Connect → Users and Access → Integrations → In-App Purchase.
	// AppleIAPPrivateKey is the .p8 file contents (PEM). Empty key disables
	// Apple verification.
	AppleBundleID       string
	AppleIssuerID       string
	AppleKeyID          string
	AppleIAPPrivateKey  string
	AppleProductMonthly string
	AppleProductYearly  string
	// AppleAPIBase overrides the App Store Server API host (tests point it
	// at a fake server). Empty tries production, then sandbox.
	AppleAPIBase string
	// FCMCredentials is the path to a Firebase service-account JSON; empty
	// disables push notifications.
	FCMCredentials string
}

func Load() (Config, error) {
	cfg := Config{
		Port:           getenv("PORT", "8080"),
		DatabaseURL:    os.Getenv("DATABASE_URL"),
		JWTSecret:      os.Getenv("JWT_SECRET"),
		AllowedOrigins: splitOrigins(os.Getenv("CORS_ALLOWED_ORIGINS")),

		AppBaseURL:            getenv("APP_BASE_URL", "http://localhost:8080"),
		TrialDays:             getenvInt("TRIAL_DAYS", 14),
		SuperadminEmails:      splitList(os.Getenv("SUPERADMIN_EMAILS")),
		SMTPHost:              os.Getenv("SMTP_HOST"),
		SMTPPort:              getenvInt("SMTP_PORT", 587),
		SMTPUser:              os.Getenv("SMTP_USER"),
		SMTPPass:              os.Getenv("SMTP_PASS"),
		SMTPFrom:              getenv("SMTP_FROM", "noreply@garage.local"),
		RazorpayKeyID:         os.Getenv("RAZORPAY_KEY_ID"),
		RazorpayKeySecret:     os.Getenv("RAZORPAY_KEY_SECRET"),
		RazorpayWebhookSecret: os.Getenv("RAZORPAY_WEBHOOK_SECRET"),
		RazorpayPlanMonthly:   os.Getenv("RAZORPAY_PLAN_MONTHLY"),
		RazorpayPlanYearly:    os.Getenv("RAZORPAY_PLAN_YEARLY"),
		RazorpayAPIBase:       getenv("RAZORPAY_API_BASE", "https://api.razorpay.com"),
		PlanPriceMonthly:      getenvInt("PLAN_PRICE_MONTHLY", 0),
		PlanPriceYearly:       getenvInt("PLAN_PRICE_YEARLY", 0),
		SiteDir:               os.Getenv("SITE_DIR"),
		AppleBundleID:         getenv("APPLE_BUNDLE_ID", "com.nexory.garage"),
		AppleIssuerID:         os.Getenv("APPLE_IAP_ISSUER_ID"),
		AppleKeyID:            os.Getenv("APPLE_IAP_KEY_ID"),
		AppleIAPPrivateKey:    strings.ReplaceAll(os.Getenv("APPLE_IAP_PRIVATE_KEY"), `\n`, "\n"),
		AppleProductMonthly:   getenv("APPLE_PRODUCT_MONTHLY", "com.nexory.garage.pro.monthly"),
		AppleProductYearly:    getenv("APPLE_PRODUCT_YEARLY", "com.nexory.garage.pro.yearly"),
		AppleAPIBase:          os.Getenv("APPLE_API_BASE"),
		FCMCredentials:        os.Getenv("FCM_CREDENTIALS"),
	}
	if cfg.DatabaseURL == "" {
		return Config{}, errors.New("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return Config{}, errors.New("JWT_SECRET is required")
	}
	if len(cfg.JWTSecret) < 16 {
		return Config{}, errors.New("JWT_SECRET must be at least 16 characters")
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getenvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}

func splitList(raw string) []string {
	var out []string
	for _, o := range strings.Split(raw, ",") {
		if o = strings.TrimSpace(o); o != "" {
			out = append(out, o)
		}
	}
	return out
}

// splitOrigins parses CORS_ALLOWED_ORIGINS="https://a,https://b".
// Empty env keeps the dev default ["*"]; set explicit origins in prod.
func splitOrigins(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return []string{"*"}
	}
	var out []string
	for _, o := range strings.Split(raw, ",") {
		if o = strings.TrimSpace(o); o != "" {
			out = append(out, o)
		}
	}
	if len(out) == 0 {
		return []string{"*"}
	}
	return out
}
