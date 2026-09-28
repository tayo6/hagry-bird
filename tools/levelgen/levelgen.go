package main

// levelgen.go - schema, validation, generation for SHAPESHOT levels.
//
// Schema (must stay in sync with game/level_data.gd):
//
//	{
//	  "meta":   { "generator": "...", "version": N, "generated_at": "RFC3339" },
//	  "levels": [
//	    {
//	      "id": "level_1", "name": "...", "projectiles": 3,
//	      "launcher":    { "position": [x, y, z] },
//	      "structures":  [ { "kind": "wood|stone|glass|rubber",
//	                         "position": [x,y,z], "size": [sx,sy,sz] } ],
//	      "targets":     [ { "position": [x,y,z], "points": 100? } ]
//	    } ]
//	}

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

const GeneratorName = "levelgen (Go)"
const SchemaVersion = 1

// ---- types ------------------------------------------------------------------

type Vec3 []float64 // exactly 3 numbers when valid

type Launcher struct {
	Position Vec3 `json:"position"`
}

type Structure struct {
	Kind     string `json:"kind"`
	Position Vec3   `json:"position"`
	Size     Vec3   `json:"size"`
	Material string `json:"material,omitempty"`
}

type Target struct {
	Position Vec3 `json:"position"`
	Points   int  `json:"points,omitempty"`
}

type Level struct {
	ID          string      `json:"id"`
	Name        string      `json:"name"`
	Projectiles int         `json:"projectiles"`
	Launcher    Launcher    `json:"launcher"`
	Structures  []Structure `json:"structures"`
	Targets     []Target    `json:"targets"`
}

type Meta struct {
	Generator   string `json:"generator"`
	Version     int    `json:"version"`
	GeneratedAt string `json:"generated_at"`
}

type Document struct {
	Meta   Meta    `json:"meta"`
	Levels []Level `json:"levels"`
}

var validMaterials = map[string]bool{
	"wood": true, "stone": true, "glass": true, "rubber": true,
}

// ---- validation ---------------------------------------------------------------

func badVec(v Vec3) bool { return len(v) != 3 }

// ValidateDocument applies the same rules as LevelData.validate() in GDScript.
func ValidateDocument(doc *Document) error {
	if len(doc.Levels) == 0 {
		return fmt.Errorf("'levels' array is empty")
	}
	for i, lv := range doc.Levels {
		p := fmt.Sprintf("levels[%d]", i)
		if lv.ID == "" {
			return fmt.Errorf("%s: missing required field 'id'", p)
		}
		if lv.Name == "" {
			return fmt.Errorf("%s: missing required field 'name'", p)
		}
		if lv.Projectiles < 1 {
			return fmt.Errorf("%s: 'projectiles' must be >= 1", p)
		}
		if badVec(lv.Launcher.Position) {
			return fmt.Errorf("%s: launcher 'position' must be [x,y,z]", p)
		}
		if len(lv.Targets) == 0 {
			return fmt.Errorf("%s: level needs at least one target", p)
		}
		for j, s := range lv.Structures {
			ps := fmt.Sprintf("%s.structures[%d]", p, j)
			if s.Kind == "" {
				return fmt.Errorf("%s: structure missing 'kind'", ps)
			}
			if !validMaterials[s.Kind] {
				return fmt.Errorf("%s: unknown material '%s'", ps, s.Kind)
			}
			if badVec(s.Position) {
				return fmt.Errorf("%s: structure missing/invalid 'position'", ps)
			}
			if badVec(s.Size) || s.Size[0] <= 0 || s.Size[1] <= 0 || s.Size[2] <= 0 {
				return fmt.Errorf("%s: structure 'size' must be 3 positive numbers", ps)
			}
			if s.Material != "" && !validMaterials[s.Material] {
				return fmt.Errorf("%s: unknown material override '%s'", ps, s.Material)
			}
		}
		for j, t := range lv.Targets {
			pt := fmt.Sprintf("%s.targets[%d]", p, j)
			if badVec(t.Position) {
				return fmt.Errorf("%s: target missing/invalid 'position'", pt)
			}
			if t.Points < 0 {
				return fmt.Errorf("%s: target 'points' must be >= 0", pt)
			}
		}
		// sanity: targets should sit roughly in front of the launcher
		for j, t := range lv.Targets {
			if t.Position[0] <= lv.Launcher.Position[0] {
				return fmt.Errorf("%s.targets[%d]: target x must be in front (+x) of launcher", p, j)
			}
		}
	}
	return nil
}

// ParseStrict rejects unknown top-level keys so typos in data files fail loudly.
func ParseStrict(raw []byte) (*Document, error) {
	var probe map[string]json.RawMessage
	if err := json.Unmarshal(raw, &probe); err != nil {
		return nil, fmt.Errorf("not valid JSON: %w", err)
	}
	if _, ok := probe["levels"]; !ok {
		return nil, fmt.Errorf("missing 'levels' array")
	}
	var doc Document
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&doc); err != nil {
		return nil, fmt.Errorf("schema mismatch: %w", err)
	}
	return &doc, nil
}

// ---- generation / file IO -------------------------------------------------------

// DefaultTestLevel builds the single small test level from the spec:
// 1 launcher, 3 projectiles, 1 structure (a small wood/glass tower), 3 targets.
func DefaultTestLevel() Level {
	return Level{
		ID: "level_1", Name: "First Tower", Projectiles: 3,
		Launcher: Launcher{Position: Vec3{-8, 0, 0}},
		Structures: []Structure{
			{Kind: "wood", Position: Vec3{6, 0, 0}, Size: Vec3{0.5, 2.4, 0.5}},
			{Kind: "wood", Position: Vec3{9, 0, 0}, Size: Vec3{0.5, 2.4, 0.5}},
			{Kind: "glass", Position: Vec3{7.5, 2.4, 0}, Size: Vec3{4.0, 0.35, 0.9}},
			{Kind: "wood", Position: Vec3{7.5, 2.75, 0}, Size: Vec3{0.5, 1.6, 0.5}},
		},
		Targets: []Target{
			{Position: Vec3{6, 2.9, 0}, Points: 100},
			{Position: Vec3{7.5, 0.55, 0.0}, Points: 100},
			{Position: Vec3{9, 2.9, 0}, Points: 100},
		},
	}
}

// VariantLevel makes a deterministic test variant (used by -seed).
func VariantLevel(n int) Level {
	lv := DefaultTestLevel()
	x := 6.0 + float64(n)*2.0
	lv.ID = fmt.Sprintf("level_test_%d", n)
	lv.Name = fmt.Sprintf("Test Variant %d", n)
	lv.Structures = lv.Structures[:2]
	lv.Structures[0].Position[0] = x
	lv.Structures[1].Position[0] = x + 3
	lv.Targets = []Target{{Position: Vec3{x + 1.5, 2.9, 0}, Points: 100}}
	return lv
}

func stamp(doc *Document) {
	doc.Meta.Generator = GeneratorName
	doc.Meta.Version = SchemaVersion
	doc.Meta.GeneratedAt = time.Now().UTC().Format(time.RFC3339)
}

// Generate reads inPath, validates, optionally appends variants, writes outPath.
func Generate(inPath, outPath string, variants int, logf func(string, ...any)) error {
	raw, err := os.ReadFile(inPath)
	if err != nil {
		return fmt.Errorf("cannot read %s: %w", inPath, err)
	}
	doc, err := ParseStrict(raw)
	if err != nil {
		return fmt.Errorf("input %s invalid: %w", inPath, err)
	}
	if err := ValidateDocument(doc); err != nil {
		return fmt.Errorf("input %s failed validation: %w", inPath, err)
	}
	base := len(doc.Levels)
	for i := 1; i <= variants; i++ {
		doc.Levels = append(doc.Levels, VariantLevel(i))
	}
	stamp(doc)
	if err := ValidateDocument(doc); err != nil {
		return fmt.Errorf("generated document failed validation: %w", err)
	}
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(outPath, append(out, '\n'), 0o644); err != nil {
		return err
	}
	logf("generated %s: %d level(s)%s", outPath, len(doc.Levels),
		map[bool]string{true: fmt.Sprintf(" (%d variants appended)", len(doc.Levels)-base), false: ""}[variants > 0])
	return nil
}

// ValidateFile re-parses and re-validates a generated file (CI gate).
func ValidateFile(path string, logf func(string, ...any)) error {
	raw, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("cannot read %s: %w", path, err)
	}
	doc, err := ParseStrict(raw)
	if err != nil {
		return fmt.Errorf("%s invalid: %w", path, err)
	}
	if err := ValidateDocument(doc); err != nil {
		return fmt.Errorf("%s failed validation: %w", path, err)
	}
	if doc.Meta.Generator == "" {
		return fmt.Errorf("%s: meta.generator missing (was this produced by levelgen generate?)", path)
	}
	logf("validated %s: %d level(s), generator=%q", path, len(doc.Levels), doc.Meta.Generator)
	return nil
}

// SelfTest exercises good + bad paths without any files.
func SelfTest(logf func(string, ...any)) error {
	good := Document{Levels: []Level{DefaultTestLevel()}}
	if err := ValidateDocument(&good); err != nil {
		return fmt.Errorf("selftest: default level rejected: %w", err)
	}
	bad := DefaultTestLevel()
	bad.Projectiles = 0
	b0 := Document{Levels: []Level{bad}}
	if ValidateDocument(&b0) == nil {
		return fmt.Errorf("selftest: zero-projectile level was accepted")
	}
	bad2 := DefaultTestLevel()
	bad2.Structures[0].Kind = "unobtainium"
	b1 := Document{Levels: []Level{bad2}}
	if ValidateDocument(&b1) == nil {
		return fmt.Errorf("selftest: unknown material was accepted")
	}
	incomplete := Document{Levels: []Level{{ID: "x"}}}
	if err := ValidateDocument(&incomplete); err == nil {
		return fmt.Errorf("selftest: incomplete level was accepted")
	}
	logf("selftest passed (good schema accepted, 3 bad schemas rejected)")
	return nil
}
