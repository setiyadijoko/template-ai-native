package main

import "testing"

func TestGreeting(t *testing.T) {
	if got := Greeting(); got != "template-ai-native consumer fixture" {
		t.Fatalf("Greeting() = %q", got)
	}
}
