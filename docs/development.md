# Development

This page tells a contributor how to set up the project, run the checks,
and add a function or a document. `CLAUDE.md` gives the rules for a commit
message and for prose.

## Set up the project

The project uses Erlang 28.3.3 and Elixir 1.19.5. With Nix, start a shell
that has Erlang 28 and Elixir 1.19:

```sh
devenv shell
```

With mise, install the exact versions:

```sh
mise install
```

Another installation of the same versions also works.

Then run these commands one time in each new clone:

```sh
mix deps.get
mix hook.install
```

`mix hook.install` tells git to use the directory `hooks`. Git then runs
`mix check` before each push.

## Run the checks

Run this command before each commit:

```sh
mix format && mix check --no-retry
```

`mix check` runs these tools in parallel:

- the compiler, with warnings as errors
- the tests
- the formatter
- Credo
- Dialyzer
- Sobelow
- `mix deps.audit`
- ExDoc
- Doctor, which examines whether each module and each public function has
  documentation and a spec
- the compiler a second time, without the optional dependency
  `phoenix_live_view`, in the directory `_build/no_optional_deps`

The first run takes some minutes, because Dialyzer must first examine
Phoenix and its dependencies. Dialyzer keeps the result in `priv/plts`, so
the next runs are fast.

## Add a function or a component

Put a function into ShoddyPhoenix only if the function needs Phoenix, a
dependency of Phoenix such as Plug, or Phoenix LiveView. Put each other
function into Shoddy.
[The design of ShoddyPhoenix](explanation/design.md) tells why.

Put a module that operates on the socket of a LiveView under
`ShoddyPhoenix.LiveView`, as `lib/shoddy_phoenix/live_view/widgets.ex` is.
Put a module for templates at the top level, as
`lib/shoddy_phoenix/control_flow.ex` is.

Give each public function a `@doc` with examples, and a `@spec`. Give each
function component an `attr` or a `slot` declaration for each input, with a
`doc:` option.

`phoenix_live_view` is an optional dependency. Put a module that needs it
inside `if Code.ensure_loaded?(...) do`, with a module of `phoenix_live_view`
that it uses. `lib/shoddy_phoenix/control_flow.ex` uses `Phoenix.Component`,
and `lib/shoddy_phoenix/live_view.ex` uses `Phoenix.LiveView`. Without that
dependency, the file then defines no module. `mix check` compiles the
project without the dependency, and it fails for a warning.

## Write tests

Give each module these tests:

- For a function that does not need a LiveView, a doctest for each example
  in its `@doc`.
- For a function component, a test that renders each example of its `@doc`
  with `Phoenix.LiveViewTest.rendered_to_string/1`.
- For a function that operates on the socket of a LiveView, a LiveView in
  `test/support` for each example of its `@doc`. A test renders that
  LiveView with `Phoenix.LiveViewTest.live/2`.
- A file with the suffix `_test.exs` in `test/`, with the usual ExUnit
  tests.
- A file with the suffix `_property_test.exs` in `test/`, with property
  tests. A property test uses StreamData to make many random inputs. It
  examines a rule that must be true for each input.

The directory `test/support` contains a test endpoint, a router and the
LiveViews of the tests. Only the test environment compiles it.
`test/test_helper.exs` starts the endpoint. `Phoenix.LiveViewTest.live/2`
needs the test dependency `lazy_html`.

To find a gap in the tests, run mutation testing:

```sh
mix test.mutation
```

Muex makes many copies of the code, and each copy has one small change. If no
test fails for a copy, the tests have a gap. `mix check` does not run this
command, and a low score does not make the command fail.

## Add a document

`mix docs` makes the documentation in the directory `doc`. Open
`doc/index.html` to see the result.

The documents follow Diátaxis, which is a method that puts each document
into one of four types. Put a new document into the directory of its type.
If the directory does not exist, make it.

| Directory | Type | Content |
| --- | --- | --- |
| `docs/tutorials` | Tutorial | A lesson for a new user. The reader does each step and sees the result. |
| `docs/how-to` | How-to guide | The steps of one task, for a user who knows the library. |
| `docs/reference` | Reference | The facts about the functions, with no steps. |
| `docs/explanation` | Explanation | The design, and the reasons for it. |

Then do these steps:

1. Add the document to the list `extras` in `mix.exs`.
2. Add the document to the list of documents in `README.md`.
3. Run each example of the document. The job `tutorials` of the workflow
   runs each tutorial, but no test runs the examples of the other documents.
4. Compare the text with the rules for prose in `CLAUDE.md`.

### Write a tutorial

A tutorial is one script for `Mix.install/2`. The reader makes the script,
and each step adds code to it. Obey these rules:

- Start the first Elixir code block with the call of `Mix.install/2`. Get
  ShoddyPhoenix with `{:shoddy_phoenix, github: "rellen/shoddy_phoenix"}`.
- Put only code of the script into an Elixir code block. Show a command in a
  `sh` block, and show output in a `text` block.
- Put tests into the script, and start ExUnit with `ExUnit.start()`. ExUnit
  then runs the tests when the script ends. Do not call `ExUnit.run/0`.
- For a LiveView, use phoenix_playground and its module
  `PhoenixPlayground.Test`.

A step can replace code of an earlier step. Put this line in front of the
earlier code block:

```text
<!-- tutorial: earlier version -->
```

Put this line in front of the code block that replaces it:

```text
<!-- tutorial: replaces the earlier version -->
```

The job `tutorials` puts the Elixir code blocks together in their order. It
puts each replacement at the place of the earlier version. Then it runs the
script with the code of the commit in place of ShoddyPhoenix from GitHub. A
script that raises or has a failed test makes the job fail.

Run the same check before a push. The first run gets and compiles the
dependencies of each tutorial, so it is slow:

```sh
elixir .github/scripts/run_tutorials.exs
```

To run one tutorial, give its path as the argument.

## The workflow

`.github/workflows/check.yml` runs the tools of `mix check` for each pull
request and for each push to `main`. The comment at the start of that file
tells which job runs each tool.

The job `mutation` runs `mix test.mutation`, and it posts the result as a
comment on the pull request. It never makes the workflow fail.

After a push to `main`, the job `pages` puts the site of `mix docs` on
https://rellen.github.io/shoddy_phoenix/. It runs only when each check
succeeded.

## Change the versions of Erlang and Elixir

Three files give the versions. Change the three files together:

| File | Content |
| --- | --- |
| `.tool-versions` | The exact versions. mise reads this file, and the session hook of Claude Code reads it too. |
| `.github/workflows/check.yml` | The exact versions, in the `env` block. |
| `devenv.nix` | The major and the minor version, in the names of the Nix packages. |
