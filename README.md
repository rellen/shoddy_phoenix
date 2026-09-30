# ShoddyPhoenix

ShoddyPhoenix is an Elixir library of small functions and components for
tasks that occur frequently in Phoenix code. It is the companion library of
[Shoddy](https://github.com/rellen/shoddy), and it obeys the same
conventions. Shoddy has no runtime dependencies, so each function that needs
Phoenix goes into ShoddyPhoenix.

This template shows a spinner, an error or the results:

```heex
<.choose>
  <:when test={@status == :loading}><.spinner /></:when>
  <:when :let={error} test={@error}><p class="error">{error}</p></:when>
  <:otherwise><.results rows={@rows} /></:otherwise>
</.choose>
```

## The modules

`ShoddyPhoenix.ControlFlow` has three function components for control flow
in HEEx templates:

- `choose/1` renders the first branch with a truthy test. It gives a
  template a readable alternative to a `<%= cond do %>` block. HEEx evaluates
  every test on every render, so read the section "Evaluation order" of
  `choose/1` before you use it.
- `switch/1` renders the first branch with a value that is equal to the value
  of the component.
- `result/1` renders `<:ok>` or `<:error>` for `{:ok, value}`, `:ok`,
  `{:error, reason}` or `:error`.

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

`ShoddyPhoenix.ControlFlow` also needs `phoenix_live_view` 1.2 or a later
version before 2.0. ShoddyPhoenix does not add `phoenix_live_view` to your
project, because it is an optional dependency. An application with HTML
pages from `mix phx.new` 1.8.15 has it already. An older application can need
the version requirement `"~> 1.2"` for `phoenix_live_view` in its `mix.exs`.

To use the components in each template, import
`ShoddyPhoenix.ControlFlow` in the function `html_helpers/0` of
`lib/my_app_web.ex`, next to your core components.

ShoddyPhoenix does not add Shoddy to your project. To use the functions of
Shoddy, add `{:shoddy, github: "rellen/shoddy"}` to the list.

## Documentation

The site https://rellen.github.io/shoddy_phoenix/ has the documentation of
each module and each document below.

To learn the library, start with the tutorial:

- [Get started with ShoddyPhoenix](docs/tutorials/get-started.md)

For one task, use a how-to guide:

- [Replace a cond block in a template](docs/how-to/replace-a-cond-block-in-a-template.md)
- [Render a result in a template](docs/how-to/render-a-result-in-a-template.md)

For the facts about a function or a component, read the page of its module.

For the reasons behind the design, read the explanation:

- [The design of ShoddyPhoenix](docs/explanation/design.md)

## Development

[Development](docs/development.md) tells how to set up the project, run the
checks, and add a function or a document. `CLAUDE.md` gives the rules for a
commit message and for prose.

## License

Apache 2.0
