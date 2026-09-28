// Command levelgen validates and generates SHAPESHOT level data.
//
// It is the Go half of the Godot+Go integration: CI runs
//
//	levelgen generate -in data/levels.json -out generated/levels.json
//	levelgen validate -in generated/levels.json
//
// and the exported Godot game reads generated/levels.json at runtime.
// No server, no network — a pure build-time data pipeline. The JSON
// schema mirrors game/level_data.gd (REQUIRED_LEVEL_FIELDS), so both
// sides must agree or the build fails loudly.
package main

import (
	"flag"
	"fmt"
	"os"
)

const usage = `levelgen - SHAPESHOT level data tool (build-time, no server)

usage:
  levelgen generate [-in data/levels.json] [-out generated/levels.json]
        Read a source level file, validate it, stamp meta and write output.
        With -seed N it also appends deterministic variant levels for testing.

  levelgen validate [-in generated/levels.json]
        Validate a level file and exit non-zero on any error.

  levelgen selftest
        Run built-in good/bad schema checks (used by scripts/test.sh).
`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	fs := flag.NewFlagSet(os.Args[1], flag.ExitOnError)
	in := fs.String("in", "", "input level JSON (default depends on subcommand)")
	out := fs.String("out", "", "output level JSON")
	seed := fs.Int("seed", 0, "if > 0, append this many deterministic test-variant levels")
	_ = fs.Parse(os.Args[2:])

	log := func(format string, a ...any) {
		fmt.Printf("[GO DATA] "+format+"\n", a...)
	}

	var err error
	switch os.Args[1] {
	case "generate":
		if *in == "" {
			*in = "data/levels.json"
		}
		if *out == "" {
			*out = "generated/levels.json"
		}
		err = Generate(*in, *out, *seed, log)
	case "validate":
		if *in == "" {
			*in = "generated/levels.json"
		}
		err = ValidateFile(*in, log)
	case "selftest":
		err = SelfTest(log)
	default:
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	if err != nil {
		log("ERROR: %v", err)
		os.Exit(1)
	}
}
