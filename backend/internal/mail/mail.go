package mail

import (
	"fmt"
	"net/smtp"
)

// Sender sends transactional email; SMTPSender is used when SMTP_HOST is set,
// LogSender (stdout) otherwise so dev/test never needs credentials.
type Sender interface {
	Send(to, subject, body string) error
}

type SMTPSender struct {
	Host, User, Pass, From string
	Port                   int
}

func (s SMTPSender) Send(to, subject, body string) error {
	msg := []byte(fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s",
		s.From, to, subject, body))
	addr := fmt.Sprintf("%s:%d", s.Host, s.Port)
	auth := smtp.PlainAuth("", s.User, s.Pass, s.Host)
	return smtp.SendMail(addr, auth, s.From, []string{to}, msg)
}

type LogSender struct{}

func (LogSender) Send(to, subject, body string) error { return nil }
