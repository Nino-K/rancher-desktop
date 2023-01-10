package main

import (
	"fmt"
	"regexp"
	"strings"
)

// This file contains handlers for specific commands.

// imageBuildHandler handles `nerdctl image build`
func imageBuildHandler(c *commandDefinition, args []string, argHandlers argHandlersType) (*parsedArgs, error) {
	// The first argument is the directory to build; the rest are ignored.
	if len(args) < 1 {
		// This will return an error
		return &parsedArgs{args: args}, nil
	}
	input := args[0]
	if input == "-" {
		return &parsedArgs{args: args}, nil
	}
	if match, _ := regexp.MatchString(`^[^:/]*://`, input); match {
		// input is a URL
		return &parsedArgs{args: args}, nil
	}
	newPath, cleanups, err := argHandlers.filePathArgHandler(args[0])
	if err != nil {
		runCleanups(cleanups)
		return nil, err
	}
	return &parsedArgs{args: append([]string{newPath}, args[1:]...), cleanup: cleanups}, nil
}

// hostPathResult is the return value of a hostPathDeterminerFunc that is used
// in containerCopyHandler for determining which argument is the host path that
// must be munged.
type hostPathResult int

const (
	hostPathUnknown = hostPathResult(iota)
	hostPathCurrent = hostPathResult(iota)
	hostPathOther   = hostPathResult(iota)
	hostPathNeither = hostPathResult(iota)
)

// containerCopyHandler handles `nerdctl container cp`
func containerCopyHandler(c *commandDefinition, args []string, argHandlers argHandlersType) (*parsedArgs, error) {
	var resultArgs []string
	var cleanups []cleanupFunc
	var paths []string

	// Positional arguments `nerdctl container cp` are all paths, whether inside
	// the container or outside.

	for _, arg := range args {
		if arg == "-" || !strings.HasPrefix(arg, "-") {
			// If the arg is "-" (stdin/stdout) or doesn't start with -, it's a path.
			paths = append(paths, arg)
		} else {
			resultArgs = append(resultArgs, arg)
		}
	}

	if len(paths) != 2 {
		// We should have exactly one source and one destination... just fail
		runCleanups(cleanups)
		return nil, fmt.Errorf("accepts 2 args, received %d", len(paths))
	}

	hostPathDeterminerFuncs := []func(i int, p string) (hostPathResult, error){
		func(i int, p string) (hostPathResult, error) {
			if p == "-" {
				// If one argument is "-", the other must be a container path, so
				// neither needs to be modified.
				return hostPathNeither, nil
			}
			return hostPathUnknown, nil
		},
		func(i int, p string) (hostPathResult, error) {
			colon := strings.Index(p, ":")
			if colon < 1 {
				// If there's no colon in the path specification at all, or if the
				// string starts with a colon (which is invalid), then this must not be
				// a container path (and therefore the other one is).
				return hostPathCurrent, nil
			}
			return hostPathUnknown, nil
		},
		func(i int, p string) (hostPathResult, error) {
			colon := strings.Index(p, ":")
			if colon > 1 {
				// There's multiple characters before the first colon; this is a container
				// path specification (foo:/path/in/container), so the other must be a
				// host path specification.
				return hostPathOther, nil
			}
			return hostPathUnknown, nil
		},
		func(i int, p string) (hostPathResult, error) {
			colon := strings.Index(p, ":")
			if colon != 1 {
				// Shouldn't get here -- one of the two previous functions should have
				// found something already.
				panic(fmt.Sprintf("Expected path %q to start with a character followed by a colon!", p))
			}
			// Fall back: the first element should be treated as the container path.
			if i == 0 {
				return hostPathOther, nil
			}
			return hostPathCurrent, nil
		},
	}

functionLoop:
	for _, f := range hostPathDeterminerFuncs {
		for i, p := range paths {
			result, err := f(i, p)
			if err != nil {
				return nil, err
			}
			hostPathIndex := i
			switch result {
			case hostPathNeither:
				resultArgs = append(resultArgs, paths...)
				break functionLoop
			case hostPathUnknown:
				continue
			case hostPathOther:
				hostPathIndex = 1 - i
			}

			// If we reach here, we found the host path to munge.
			if hostPathIndex == 1 {
				resultArgs = append(resultArgs, paths[0])
			}
			newPath, newCleanups, err := argHandlers.filePathArgHandler(paths[hostPathIndex])
			if err != nil {
				cleanups = append(cleanups, newCleanups...)
				runCleanups(cleanups)
				return nil, err
			}
			resultArgs = append(resultArgs, newPath)
			if hostPathIndex != 1 {
				resultArgs = append(resultArgs, paths[1])
			}
			break functionLoop
		}
	}

	return &parsedArgs{args: resultArgs, cleanup: cleanups}, nil
}
