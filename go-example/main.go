// main.go
package main

import (
	"bufio"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	// Header (keeps the extra blank line like the Java version)
	fmt.Println("Java-args-env-file V4\n")

	// --- Command Line Arguments ---
	fmt.Println("Command Line Arguments:")
	for i, a := range os.Args[1:] {
		fmt.Printf("arg[%d]: %s\n", i, a)
	}

	// --- Environment Variables ---
	fmt.Println("\nEnvironment Variables:")
	for _, e := range os.Environ() { // format: "KEY=VALUE"
		// Print as-is to mirror Java's default (unsorted) order
		fmt.Println(e)
	}

	// --- Files ---
	readAndPrintFile("/config/configs.yaml", "Config File")
	readAndPrintFile("/config/secrets", "Secrets File")

	// --- Sleep for 1 hour (interrupt-aware) ---
	fmt.Println("\nSleeping for 1 minute to keep the container alive...")
	timer := time.NewTimer(1 * time.Minute)
	defer timer.Stop()

	// Catch interrupt/termination like Java's InterruptedException
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case <-timer.C:
		// Slept the full hour
	case sig := <-sigCh:
		// Report interruption to stderr (matches Java's System.err)
		fmt.Fprintf(os.Stderr, "Sleep interrupted: %v\n", sig)
	}

	fmt.Println("Done.")
}

func readAndPrintFile(path, label string) {
	fmt.Printf("\n%s (%s):\n", label, path)

	f, err := os.Open(path)
	if err != nil {
		fmt.Printf("Failed to read %s: %v\n", path, err)
		return
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	// Allow long lines (increase from default 64K)
	const maxCapacity = 10 * 1024 * 1024 // 10 MiB
	buf := make([]byte, 0, 1024*64)
	sc.Buffer(buf, maxCapacity)

	for sc.Scan() {
		// Print each line as-is (like Files.lines in Java)
		fmt.Println(sc.Text())
	}
	if err := sc.Err(); err != nil {
		// Scanner I/O error
		fmt.Printf("Failed to read %s: %v\n", path, err)
	}
}

// Optional helper if you ever need key/value split:
//
// func splitEnv(e string) (key, val string) {
// 	if i := strings.IndexByte(e, '='); i >= 0 {
// 		return e[:i], e[i+1:]
// 	}
// 	return e, ""
// }
