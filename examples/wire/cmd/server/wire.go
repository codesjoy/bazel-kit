//go:build wireinject

package main

import "github.com/google/wire"

func initializeApp() *App {
	wire.Build(provideConfig, newApp)
	return nil
}
