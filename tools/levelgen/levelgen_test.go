package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestDefaultLevelValid(t *testing.T) {
	doc := Document{Levels: []Level{DefaultTestLevel()}}
	if err := ValidateDocument(&doc); err != nil {
		t.Fatalf("default test level must validate, got: %v", err)
	}
	lv := DefaultTestLevel()
	if lv.Projectiles != 3 {
		t.Errorf("spec says 3 projectiles, got %d", lv.Projectiles)
	}
	if len(lv.Targets) != 3 {
		t.Errorf("spec says 3 targets, got %d", len(lv.Targets))
	}
}

func TestRejectMissingFields(t *testing.T) {
	cases := map[string]func(*Level){
		"no id":         func(l *Level) { l.ID = "" },
		"no name":       func(l *Level) { l.Name = "" },
		"zero shots":    func(l *Level) { l.Projectiles = 0 },
		"no targets":    func(l *Level) { l.Targets = nil },
		"bad vec":       func(l *Level) { l.Launcher.Position = Vec3{1, 2} },
		"target behind": func(l *Level) { l.Targets[0].Position = Vec3{-99, 1, 0} },
	}
	for name, mutate := range cases {
		lv := DefaultTestLevel()
		mutate(&lv)
		doc := Document{Levels: []Level{lv}}
		if err := ValidateDocument(&doc); err == nil {
			t.Errorf("%s: expected validation error, got none", name)
		}
	}
}

func TestRejectBadMaterialAndSize(t *testing.T) {
	lv := DefaultTestLevel()
	lv.Structures[0].Kind = "cheese"
	doc := Document{Levels: []Level{lv}}
	if err := ValidateDocument(&doc); err == nil {
		t.Error("unknown material should fail")
	}
	lv2 := DefaultTestLevel()
	lv2.Structures[0] = Structure{Kind: "wood", Position: Vec3{1, 2, 3}, Size: Vec3{0, 1, 1}}
	doc2 := Document{Levels: []Level{lv2}}
	if err := ValidateDocument(&doc2); err == nil {
		t.Error("non-positive size should fail")
	}
}

func TestParseStrictRejectsUnknownKeys(t *testing.T) {
	raw := `{"levels":[{"id":"a","name":"b","projectiles":1,"launcher":{"position":[0,0,0]},
		"structures":[],"targets":[{"position":[1,1,1]}],"typo_key":true}]}`
	if _, err := ParseStrict([]byte(raw)); err == nil {
		t.Fatal("unknown key 'typo_key' must be rejected")
	}
}

func TestGenerateRoundTrip(t *testing.T) {
	dir := t.TempDir()
	in := filepath.Join(dir, "in.json")
	out := filepath.Join(dir, "gen", "levels.json")
	src := Document{Levels: []Level{DefaultTestLevel()}}
	b, _ := json.MarshalIndent(src, "", "  ")
	if err := os.WriteFile(in, b, 0o644); err != nil {
		t.Fatal(err)
	}
	log := func(string, ...any) {}
	if err := Generate(in, out, 2, log); err != nil {
		t.Fatalf("generate failed: %v", err)
	}
	if err := ValidateFile(out, log); err != nil {
		t.Fatalf("generated file failed validation: %v", err)
	}
	raw, _ := os.ReadFile(out)
	var doc Document
	if err := json.Unmarshal(raw, &doc); err != nil {
		t.Fatal(err)
	}
	if len(doc.Levels) != 3 { // base + 2 variants
		t.Errorf("expected 3 levels, got %d", len(doc.Levels))
	}
	if doc.Meta.Generator != GeneratorName {
		t.Errorf("meta.generator not stamped: %q", doc.Meta.Generator)
	}
}

func TestSelfTest(t *testing.T) {
	if err := SelfTest(func(string, ...any) {}); err != nil {
		t.Fatal(err)
	}
}

// TestRepoDataFile validates the committed data/levels.json if present.
func TestRepoDataFile(t *testing.T) {
	path := filepath.Join("..", "..", "data", "levels.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Skip("repo data/levels.json not found (running outside repo?)")
	}
	doc, err := ParseStrict(raw)
	if err != nil {
		t.Fatalf("data/levels.json invalid: %v", err)
	}
	if err := ValidateDocument(doc); err != nil {
		t.Fatalf("data/levels.json failed validation: %v", err)
	}
}
