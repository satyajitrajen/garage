package auth

import "golang.org/x/crypto/bcrypt"

const bcryptCost = 12

// dummyHash costs one bcrypt-12 comparison at init so login can burn the same
// work for unknown emails and not leak account existence via timing.
var dummyHash = func() []byte {
	h, _ := bcrypt.GenerateFromPassword([]byte("garage-dummy-password"), bcryptCost)
	return h
}()

func HashPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcryptCost)
	return string(hash), err
}

func CheckPassword(hash, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}

// CompareDummy equals the cost of a real CheckPassword for unknown users.
func CompareDummy(password string) {
	_ = bcrypt.CompareHashAndPassword(dummyHash, []byte(password))
}
