# ShoddyPhoenix

ShoddyPhoenix is an Elixir library of small functions for tasks that occur
frequently in Phoenix code. It is the companion library of
[Shoddy](https://github.com/rellen/shoddy).

Shoddy uses only the standard library of Elixir. A function that needs
Phoenix goes into ShoddyPhoenix. Thus a project that does not use Phoenix
can use Shoddy, and it does not get Phoenix as a dependency.

## The modules

ShoddyPhoenix has no functions yet. This list will name each module that
contains functions.

## Installation

ShoddyPhoenix is not on Hex. Add ShoddyPhoenix from GitHub to the list of
dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:shoddy_phoenix, github: "rellen/shoddy_phoenix"}
  ]
end
```

ShoddyPhoenix needs Elixir 1.19 or a later version. It also needs Phoenix
1.8 or a later version before 2.0.

## Documentation

The site https://rellen.github.io/shoddy_phoenix/ has the documentation of
each module and each document below.

For the reasons behind the design, read the explanation:

- [The design of ShoddyPhoenix](docs/explanation/design.md)

## Development

[Development](docs/development.md) tells how to get the tools, run the
checks and add a document. `CLAUDE.md` gives the rules for a commit message
and for prose.

## License

Apache 2.0
