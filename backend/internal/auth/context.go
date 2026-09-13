package auth

import "context"

type ctxKey int

const (
	ctxUserID ctxKey = iota
	ctxGarageID
	ctxRole
	ctxPermissions
)

func UserID(ctx context.Context) string {
	v, _ := ctx.Value(ctxUserID).(string)
	return v
}

func GarageID(ctx context.Context) string {
	v, _ := ctx.Value(ctxGarageID).(string)
	return v
}

func Role(ctx context.Context) string {
	v, _ := ctx.Value(ctxRole).(string)
	return v
}

func Permissions(ctx context.Context) []string {
	v, _ := ctx.Value(ctxPermissions).([]string)
	return v
}
