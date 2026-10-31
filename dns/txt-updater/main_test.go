package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestZoneEndpointServesRawFileBehindToken(t *testing.T) {
	zonePath = filepath.Join(t.TempDir(), "dynamic.db")
	want := "$ORIGIN srv.nomercy.tv.\n@ IN SOA ns1.nomercy.tv. hostmaster.nomercy.tv. ( 1 ; serial\n 7200 3600 1209600 60 )\n"
	if err := os.WriteFile(zonePath, []byte(want), 0o644); err != nil {
		t.Fatal(err)
	}
	token = "test-token"

	rec := httptest.NewRecorder()
	zone(rec, httptest.NewRequest(http.MethodGet, "/zone", nil))
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("no token: want 401, got %d", rec.Code)
	}

	req := httptest.NewRequest(http.MethodGet, "/zone", nil)
	req.Header.Set("Authorization", "Bearer test-token")
	rec = httptest.NewRecorder()
	zone(rec, req)
	if rec.Code != http.StatusOK || rec.Body.String() != want {
		t.Fatalf("with token: want 200 and the exact file, got %d %q", rec.Code, rec.Body.String())
	}

	req = httptest.NewRequest(http.MethodPost, "/zone", nil)
	req.Header.Set("Authorization", "Bearer test-token")
	rec = httptest.NewRecorder()
	zone(rec, req)
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("POST: want 405, got %d", rec.Code)
	}
}

func TestAddTxtBumpsSerialAndAppends(t *testing.T) {
	zone := "$ORIGIN srv.nomercy.tv.\n$TTL 60\n@ IN SOA ns1.nomercy.tv. hostmaster.nomercy.tv. (\n        2026070301 ; serial\n        7200 3600 1209600 60 )\n@ IN NS ns1.nomercy.tv.\n"
	out, err := addTxt(zone, "_acme-challenge.10-0-0-7.abc.srv.nomercy.tv", "tok123")
	if err != nil {
		t.Fatalf("addTxt error: %v", err)
	}
	if !strings.Contains(out, `_acme-challenge.10-0-0-7.abc.srv.nomercy.tv. 60 IN TXT "tok123"`) {
		t.Fatalf("TXT record not appended:\n%s", out)
	}
	if !strings.Contains(out, "2026070302 ; serial") {
		t.Fatalf("serial not bumped:\n%s", out)
	}
}

func TestDeleteTxtRemovesLineAndBumpsSerial(t *testing.T) {
	zone := "$ORIGIN srv.nomercy.tv.\n$TTL 60\n@ IN SOA ns1.nomercy.tv. hostmaster.nomercy.tv. (\n        2026070302 ; serial\n        7200 3600 1209600 60 )\n@ IN NS ns1.nomercy.tv.\n_acme-challenge.10-0-0-7.abc.srv.nomercy.tv. 60 IN TXT \"tok123\"\n"
	out, err := deleteTxt(zone, "_acme-challenge.10-0-0-7.abc.srv.nomercy.tv")
	if err != nil {
		t.Fatalf("deleteTxt error: %v", err)
	}
	if strings.Contains(out, "tok123") {
		t.Fatalf("TXT record not removed:\n%s", out)
	}
	if !strings.Contains(out, "2026070303 ; serial") {
		t.Fatalf("serial not bumped:\n%s", out)
	}
}

func TestNameRegexRejectsGarbage(t *testing.T) {
	bad := []string{
		"example.com",
		"_acme-challenge.srv.nomercy.tv",
		"_acme-challenge.10-0-0-7.abc.srv.nomercy.tv.evil.com",
	}
	for _, b := range bad {
		if nameRe.MatchString(b) {
			t.Fatalf("regex should reject %q", b)
		}
	}
	if !nameRe.MatchString("_acme-challenge.10-0-0-7.abc.srv.nomercy.tv") {
		t.Fatal("regex should accept a per-host challenge name")
	}
	if !nameRe.MatchString("_acme-challenge.9ac70a94-d4ca-dd69-9a65-79229718f7db.srv.nomercy.tv") {
		t.Fatal("regex should accept a wildcard-cert challenge name (single uuid label)")
	}
}
