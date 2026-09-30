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

The first run takes some minutes, because Dialyzer must first examine
Phoenix and its dependencies. Dialyzer keeps the result in `priv/plts`, so
the next runs are fast.

## Add a function

Put a function into ShoddyPhoenix only if the function needs Phoenix, or a
dependency of Phoenix such as Plug. Put each other function into Shoddy.
[The design of ShoddyPhoenix](explanation/design.md) tells why.

Give each public function a `@doc` with examples, and a `@spec`.

The library has no public function yet. The change that adds the first
public function must also change two thresholds in `.doctor.exs` to 100.
The comment in that file tells why.

## Write tests

Give each module these tests:

- A doctest for each example in its `@doc`.
- A file with the suffix `_test.exs` in `test/`, with the usual ExUnit
  tests.
- A file with the suffix `_property_test.exs` in `test/`, with property
  tests. A property test uses StreamData to make many random inputs. It
  examines a rule that must be true for each input.

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
3. Run each example of the document. No test runs the examples of a
   document in `docs`.
4. Compare the text with the rules for prose in `CLAUDE.md`.

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
