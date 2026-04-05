package main

type Config struct {
	Address string
}

type App struct {
	Config Config
}

func provideConfig() Config {
	return Config{Address: "127.0.0.1:8080"}
}

func newApp(config Config) *App {
	return &App{Config: config}
}
