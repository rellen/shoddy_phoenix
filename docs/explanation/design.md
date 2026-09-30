# The design of ShoddyPhoenix

This page tells why ShoddyPhoenix is a separate library, and which rules its
functions obey.

## Two libraries

Shoddy has small functions for tasks that occur frequently in Elixir code.
Shoddy has no runtime dependencies. Thus a project that uses Shoddy gets no
other package.

Some tasks occur frequently only in a Phoenix application. A function for
such a task needs Phoenix, or a dependency of Phoenix such as Plug. If Shoddy
contains that function, each project that uses Shoddy gets Phoenix as a
dependency. Then a library or a command-line tool that does not use Phoenix
compiles Phoenix for no purpose.

Thus these functions go into a second library, ShoddyPhoenix. Each project
uses only the library that it needs:

| Project | Libraries |
| --- | --- |
| A project that does not use Phoenix | Shoddy |
| A Phoenix application | Shoddy, ShoddyPhoenix, or the two libraries |

## The library of a new function

Use these rules to select the library for a new function:

1. If the function needs only the standard library of Elixir, put it into
   Shoddy.
2. If the function needs Phoenix, or a dependency of Phoenix such as Plug,
   put it into ShoddyPhoenix.

A dependency between the two libraries can go in one direction only.
ShoddyPhoenix can have Shoddy as a dependency. Shoddy never has
ShoddyPhoenix as a dependency, because Shoddy must not get Phoenix.

## The same conventions as Shoddy

ShoddyPhoenix obeys the conventions of Shoddy. Thus a person who uses the
two libraries learns only one set of rules.
[The conventions of the functions](https://github.com/rellen/shoddy/blob/main/docs/reference/conventions.md)
in Shoddy gives these conventions. These are some examples:

- The first argument is the value that the function operates on. For
  example, a function that operates on a connection takes the `Plug.Conn`
  struct first. The functions of `Plug.Conn` and `Phoenix.Controller` obey
  the same rule. Thus each function can be a step of a pipeline.
- A name that ends in `?` is the name of a function that returns a boolean.
- A name that ends in `!` is the name of a function that raises an
  exception for an error result.

## Phoenix is the only runtime dependency

ShoddyPhoenix needs Phoenix 1.8 or a later version before 2.0. A Phoenix
application that obeys this requirement already has Phoenix. Thus
ShoddyPhoenix adds no other package to such an application.

Each other dependency in `mix.exs` is for development or for tests only.
