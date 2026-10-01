# AI Agent Guidelines

## Critical: Write All Documentation in ASD-STE100

**All documentation in this repository must obey ASD-STE100 Simplified
Technical English. This rule is not optional. Do not write documentation in
any other style.**

This document says STE for ASD-STE100 after this point. STE keeps text
short, active, and unambiguous. A reader who does not speak
English as a first language can then read the text correctly. A machine
translation of the text also stays correct. A reader must never need to guess
what a sentence means.

This rule applies to all of these:

- `README.md` and every other Markdown file
- Every `@moduledoc`, `@doc`, and `@typedoc`
- Every code comment, in Elixir files and in shell scripts
- Every description in a `test` block or a `describe` block
- Every message that a script prints
- The `description` field in `mix.exs`

Obey these nine rules each time you write or change that text:

1. Write one instruction in one sentence. Keep a procedural sentence shorter
   than 20 words. Keep a descriptive sentence shorter than 25 words.
2. Use the active voice. Write "The function ignores a falsy value". Do not
   write "Falsy values are skipped".
3. Do not use the -ing form. Write "Functions that operate on maps". Do not
   write "Functions for working with maps". The -ing form is permitted only
   inside a technical name, such as "functional programming".
4. Write complete sentences. Do not remove words to make a sentence shorter.
   Give every sentence a subject.
5. Use articles. Write "an ok tuple". Do not write "ok tuple".
6. Use one term for one thing. Do not use a second word for variety. This
   repository says "puts a value into". It never says "wraps a value in".
   It says "returns" for the result of a function. It never says "gives
   back".
7. Do not use slang, idiom, or undefined jargon. Define each technical term
   at the place where you first use it.
8. Keep the punctuation simple. Do not use an em dash. Do not use a slash
   between two words. Use a vertical list for complex text.
9. Do not use an abbreviation that this repository does not define. Write
   "for example". Do not write "e.g.".

There is one permitted exception. The summary line of a `@doc` can keep the
usual Elixir form. That line can start with a verb, as in "Applies a function
to a value". That line is the title of the entry in the generated
documentation, and STE permits a short form in a title.

Read your text again before each commit. Check it against the nine rules
above. A change that adds documentation in another style is not complete.

## The Scope of This Library

ShoddyPhoenix is the companion library of Shoddy, at
https://github.com/rellen/shoddy. Obey these rules for each new function:

- Put a function into ShoddyPhoenix only if the function needs Phoenix, a
  dependency of Phoenix such as Plug, or Phoenix LiveView.
- Put each other function into Shoddy. Shoddy has no runtime dependencies,
  and it must never get Phoenix.
- Obey the conventions of Shoddy. The file `docs/reference/conventions.md`
  of Shoddy gives them. For example, the first argument is the value that
  the function operates on.
- Use the same terms as Shoddy, as rule 6 above tells.
- Phoenix is the only required runtime dependency. `phoenix_live_view` is
  an optional dependency. Do not add another dependency before you discuss
  it with the maintainer.
- Put a module that operates on the socket of a LiveView under
  `ShoddyPhoenix.LiveView`. Put a module for templates, such as a module of
  function components, at the top level.
- Put a module that needs `phoenix_live_view` inside
  `if Code.ensure_loaded?(...) do`, with a module of `phoenix_live_view` that
  it uses, such as `Phoenix.Component` or `Phoenix.LiveView`. Then a project
  without LiveView can still compile ShoddyPhoenix.
- Test each function component with
  `Phoenix.LiveViewTest.rendered_to_string/1`. Test each function that
  operates on the socket of a LiveView through a LiveView in `test/support`,
  with `Phoenix.LiveViewTest.live/2`. Give each claim of a `@doc` or a
  `@moduledoc` a test.

`docs/explanation/design.md` gives the reasons for these rules.

## Commit Messages

- Use the conventional commits format: `type(scope): description`.
- Use one of these types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`,
  `ci`.
- Keep the subject line shorter than 72 characters.
- Write the subject in the imperative mood. For example, write "add feature",
  not "added feature".
- Add a body to each commit that is not trivial. In the body, tell why you
  made the change.
- Write the body in ASD-STE100. Obey the rules in the first section.

## Versions and Releases

- Change the version in `mix.exs` only in a release. Do not change it in
  another pull request.
- If a pull request changes the behavior of the library, add one line for
  each change to the section "Unreleased" of `CHANGELOG.md`. A change to the
  documentation, the tests or the workflow alone does not need a line.
- Start the line of a breaking change with "Breaking:". A breaking change is
  a change that can make correct code of a caller fail. For example, a new
  name for a module or a function is a breaking change. The removal of a
  function is also a breaking change.
- Make each release in a separate pull request. That pull request does these
  steps:
  1. It selects the new version with the rules below.
  2. It changes the version in `mix.exs`.
  3. It gives the section "Unreleased" of `CHANGELOG.md` the new version and
     the date as its title. It then adds a new section "Unreleased" with no
     lines.
- After the merge of a release, add a tag with the version to the merge
  commit. For example, the tag of version 0.4.0 is `v0.4.0`.
- While the major version is 0, select the version with these rules:
  - A breaking change increases the minor version. For example, 0.3.0
    becomes 0.4.0.
  - Another change increases the patch version. For example, 0.3.0 becomes
    0.3.1.
- From version 1.0.0, obey Semantic Versioning:
  - A breaking change increases the major version.
  - A new function increases the minor version.
  - A correction increases the patch version.

## How to Work on This Project

- This project uses Elixir. Mix is the build tool.
- Run `mix format && mix check --no-retry` before each commit. This command
  formats the code and does all the checks.
- Use `mix check --no-retry`. It does all the checks in parallel. The checks
  include the compiler, the tests, Credo, and Dialyzer.
- Do not run `mix test`, `mix compile --warnings-as-errors`, or `mix credo` as
  separate commands. `mix check` does all of them.
- Run `mix hook.install` one time in each new clone. That command tells git to
  use the `hooks` directory of this project. Git then runs `mix check` before
  each push.
- Run `mix test.mutation` to find a gap in the tests. This alias runs muex,
  which is a tool for mutation testing. The command `mix check` does not run
  this alias. A low score does not make this alias fail.
- Mutation testing makes many copies of the code. Each copy has one small
  change, and it is a mutant. If a test fails for a mutant, the tests kill
  that mutant. If no test fails, the mutant survives, and the tests have a
  gap. Examine each mutant that survives.
- Do not trust the count of invalid mutants. Muex sometimes reports a mutant
  as invalid, although the mutant compiles and the tests kill it. Two runs of
  the same code can give different invalid mutants.
- The workflow `.github/workflows/check.yml` runs each tool of `mix check` for
  each pull request, in separate jobs. A defect that one tool finds makes the
  check fail.
- The job `mutation` of that workflow runs `mix test.mutation` after the
  tests succeed. That job reports the result, and it never makes a check fail.
  It puts a warning on the line of each mutant that survives.
- For a pull request, the job `mutation` also posts its summary as a comment.
  The job keeps one comment for each pull request, and each run replaces its
  text. The comment names the commit that it describes.
- The workflow has its own copy of the versions of `.tool-versions`. Change
  the versions in `.tool-versions`, `devenv.nix` and the workflow together.
- After a push to `main`, the job `pages` of that workflow puts the site of
  `mix docs` on GitHub Pages. The job runs only when each check succeeded.
- The documents in `docs` follow Diátaxis. Put a new document into the
  directory of its type, and add it to `mix.exs` and `README.md`.
  `docs/development.md` gives the four types.
- Run each example of a new document before you commit it. No test runs
  the examples of a document in `docs`.

## Code Style

- Obey the usual Elixir conventions and the `.formatter.exs` file of the
  project, if that file is present.
- Write every comment, `@moduledoc`, `@doc`, `@typedoc`, and test
  description in ASD-STE100. Obey
  the rules in the first section.
- Do not add a dependency before you discuss it with the maintainer.
- Keep each module small. Give each module one clear purpose.

## Branch Strategy

- Make each feature branch from `main`.
- Give each branch a descriptive name. Put the change type at the start of the
  name. For example: `feat/add-parser` or `fix/timeout-issue`.
