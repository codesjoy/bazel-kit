package main

import "fmt"

func main() {
	fmt.Println(message("world"))
}

func message(name string) string {
	return "hello, " + name
}
