package notifysync

import (
	"flag"
	"os"
	"path/filepath"
)

type ClientFlags struct{ base, public, token, button *string }

func RegisterClientFlags(fs *flag.FlagSet) ClientFlags {
	base := os.Getenv("NOTIFY_URL")
	if base == "" {
		base = "https://ntfy.hummingbird-lake.ts.net"
	}
	public := os.Getenv("NOTIFY_PUBLIC_URL")
	if public == "" {
		public = base
	}
	return ClientFlags{fs.String("ntfy", base, "ntfy base URL"), fs.String("public-url", public, "public URL used in buttons"), fs.String("token-file", os.Getenv("NOTIFY_TOKEN_FILE"), "ntfy token file"), fs.String("button-token-file", os.Getenv("NOTIFY_BUTTON_TOKEN_FILE"), "write-only notify-ctl token file")}
}
func (f ClientFlags) Client() (*Client, error) {
	token, err := ReadToken(*f.token)
	if err != nil {
		return nil, err
	}
	button, err := ReadToken(*f.button)
	if err != nil {
		return nil, err
	}
	return NewClient(*f.base, *f.public, token, button)
}
func StateDirectory() string {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".local/state")
	}
	return filepath.Join(base, "notify-sync")
}
