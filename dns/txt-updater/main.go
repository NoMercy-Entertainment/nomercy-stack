package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
)

var (
	zonePath = envOr("ZONE_PATH", "/etc/coredns/zones/dynamic.db")
	token    = os.Getenv("TXT_UPDATER_TOKEN")
	// Accepts the wildcard-cert challenge `_acme-challenge.<server-uuid>.srv.nomercy.tv`
	// and the per-host form `_acme-challenge.<host>.<server-uuid>.srv.nomercy.tv`.
	nameRe   = regexp.MustCompile(`^_acme-challenge\.([^.]+\.)?[0-9a-fA-F-]+\.srv\.nomercy\.tv$`)
	serialRe = regexp.MustCompile(`(\d{10})(\s*;\s*serial)`)
	mu       sync.Mutex
)

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

// bumpSerial increments the first 10-digit SOA serial that is tagged "; serial".
func bumpSerial(zone string) string {
	return serialRe.ReplaceAllStringFunc(zone, func(m string) string {
		sub := serialRe.FindStringSubmatch(m)
		n, _ := strconv.ParseInt(sub[1], 10, 64)
		return strconv.FormatInt(n+1, 10) + sub[2]
	})
}

func addTxt(zone, name, value string) (string, error) {
	line := fmt.Sprintf("%s. 60 IN TXT %q\n", name, value)
	zone = bumpSerial(zone)
	if !strings.HasSuffix(zone, "\n") {
		zone += "\n"
	}
	return zone + line, nil
}

func deleteTxt(zone, name string) (string, error) {
	needle := name + ". "
	var kept []string
	for _, l := range strings.Split(zone, "\n") {
		if strings.HasPrefix(l, needle) && strings.Contains(l, "TXT") {
			continue
		}
		kept = append(kept, l)
	}
	return bumpSerial(strings.Join(kept, "\n")), nil
}

func atomicWrite(path, content string) error {
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, []byte(content), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

type req struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

func authed(r *http.Request) bool {
	return token != "" && r.Header.Get("Authorization") == "Bearer "+token
}

func handle(w http.ResponseWriter, r *http.Request) {
	if !authed(r) {
		http.Error(w, `{"ok":false,"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}
	var body req
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || !nameRe.MatchString(body.Name) {
		http.Error(w, `{"ok":false,"error":"bad name"}`, http.StatusBadRequest)
		return
	}
	mu.Lock()
	defer mu.Unlock()
	raw, err := os.ReadFile(zonePath)
	if err != nil {
		http.Error(w, `{"ok":false,"error":"zone read"}`, http.StatusInternalServerError)
		return
	}
	var out string
	switch r.Method {
	case http.MethodPost:
		out, err = addTxt(string(raw), body.Name, body.Value)
	case http.MethodDelete:
		out, err = deleteTxt(string(raw), body.Name)
	default:
		http.Error(w, `{"ok":false,"error":"method"}`, http.StatusMethodNotAllowed)
		return
	}
	if err != nil || atomicWrite(zonePath, out) != nil {
		http.Error(w, `{"ok":false,"error":"write"}`, http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"ok":true}`))
}

func main() {
	if token == "" {
		log.Fatal("TXT_UPDATER_TOKEN must be set")
	}
	http.HandleFunc("/txt", handle)
	addr := envOr("LISTEN", "0.0.0.0:8081")
	log.Printf("txt-updater listening on %s (zone=%s)", addr, zonePath)
	log.Fatal(http.ListenAndServe(addr, nil))
}
