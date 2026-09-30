# Development

This page tells a contributor how to get the tools, run the checks, add a
function and add a document. `CLAUDE.md` gives the rules for a commit
message and for prose.

## Get the tools

The project uses Erlang 28.3.3 and Elixir 1.19.5. Four files give these
versions. Change the four files together:

| File | Use |
| --- | --- |
| `.tool-versions` | mise reads this file. |
| `devenv.nix` | devenv gives the versions in a Nix shell. |
| `.claude/hooks/session-start.sh` | The hook reads `.tool-versions`, and it installs the versions with mise in a remote session of Claude Code. |
| `.github/workflows/check.yml` | The `env` block gives the versions to each job. |

With Nix, start a shell that has the tools:

```sh
devenv shell
```

With mise, install the tools:

```sh
mise install
```

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

## Add a function

Put a function into ShoddyPhoenix only if the function needs Phoenix, or a
dependency of Phoenix such as Plug. Put each other function into Shoddy.
[The design of ShoddyPhoenix](explanation/design.md#the-library-of-a-new-function)
tells why.

Give each public function a `@doc` with examples, and a `@spec`. Doctor
examines whether each public function has them.

The library has no public function yet. The change that adds the first
public function must also change two thresholds in `.doctor.exs` to 100.
The comment in that file tells why.

## Write tests

The project has three kinds of tests:

- A doctest is an example in a `@doc`. `mix test` runs each example and
  compares the result with the text of the example.
- A property test uses StreamData to make many random inputs. It examines a
  rule that must be true for each input. Give each module a file with the
  suffix `_property_test.exs` in `test/`.
- Mutation testing finds a gap in the tests. Muex makes many copies of the
  code, and each copy has one small change. If no test fails for a copy, the
  tests have a gap. Run it with this command:

  ```sh
  mix test.mutation
  ```

  `mix check` does not run this command, and a low score does not make the
  command fail.

## Add a document

`mix docs` makes the documentation in the directory `doc`. Open
`doc/index.html` to see the result. The site
https://rellen.github.io/shoddy_phoenix/ shows the result of the last push
to `main`.

The documents follow Diátaxis, which is a method that puts each document
into one of four types. Put a new document into the directory of its type:

| Directory | Type | Content |
| --- | --- | --- |
| `docs/tutorials` | Tutorial | A lesson for a new user. The reader does each step and sees the result. |
| `docs/how-to` | How-to guide | The steps of one task, for a user who knows the library. |
| `docs/reference` | Reference | The facts about the functions, with no steps. |
| `docs/explanation` | Explanation | The design, and the reasons for it. |

If the directory does not exist, make it.

The page of each module is also a reference. Its `@moduledoc` and each
`@doc` give the facts about the functions.

Then do these steps:

1. Add the document to the list `extras` in `mix.exs`.
2. Add the document to the list of documents in `README.md`.
3. Run each example of the document. No test runs the examples of a
   document in `docs`.
4. Read the text again, and compare it with the rules for prose in
   `CLAUDE.md`.

## The workflow

`.github/workflows/check.yml` runs the checks for each pull request and for
each push to `main`. Each job runs some of the tools of `mix check`. The
comment at the start of the file gives the list.

The job `mutation` runs `mix test.mutation` after the tests succeed. It
reports the result only, and it never makes the workflow fail. The summary
of the run shows the result. For a pull request, the job also posts the
summary as a comment.

After a push to `main`, the job `pages` puts the site of `mix docs` on
GitHub Pages. The job `lint` makes the site, and it uploads the directory
`doc` when each of its steps succeeded. Thus the site and the checks come
from one build. The job `pages` needs the job `all`, so it starts only when
each check succeeded. A push to `main` with a failed check keeps the old
site.

The repository must have Pages on, with GitHub Actions as the source. A
person must turn it on in the settings of the repository, under "Pages",
because the token of a workflow cannot turn it on. A run of `pages` without
the site fails at the step `configure-pages`.
