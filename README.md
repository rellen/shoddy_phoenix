# ShoddyPhoenix

ShoddyPhoenix is an Elixir library of small functions for tasks that occur
frequently in Phoenix code. It is the companion library of
[Shoddy](https://github.com/rellen/shoddy), and it obeys the same
conventions. Shoddy has no runtime dependencies, so each function that needs
Phoenix goes into ShoddyPhoenix.

ShoddyPhoenix has no functions yet.

## Installation

ShoddyPhoenix is not on Hex. Add it from GitHub to the list of dependencies
in `mix.exs`:

```elixir
defp deps do
  [
    {:shoddy_phoenix, github: "rellen/shoddy_phoenix"}
  ]
end
```

ShoddyPhoenix needs Elixir 1.19 or a later version. It also needs Phoenix
1.8 or a later version before 2.0.

ShoddyPhoenix does not add Shoddy to your project. To use the functions of
Shoddy, add `{:shoddy, github: "rellen/shoddy"}` to the list.

## Documentation

The site https://rellen.github.io/shoddy_phoenix/ has the documentation of
each module and each document below.

- [The design of ShoddyPhoenix](docs/explanation/design.md) tells why
  ShoddyPhoenix is a separate library.

## Development

[Development](docs/development.md) tells how to set up the project, run the
checks, and add a function or a document. `CLAUDE.md` gives the rules for a
commit message and for prose.

## License

Apache 2.0
