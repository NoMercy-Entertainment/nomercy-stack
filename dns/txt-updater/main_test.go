package main

import "strings"

import "testing"

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
		t.Fatal("regex should accept a valid challenge name")
	}
}
