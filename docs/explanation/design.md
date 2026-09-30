# The design of ShoddyPhoenix

This page tells why ShoddyPhoenix is a separate library from Shoddy, and why
its components behave as they do.

## Why a separate library

Shoddy has no runtime dependencies. Thus a library or a command-line tool
can use Shoddy, and it gets no other package.

Some tasks occur frequently only in Phoenix code. A function for such a task
needs Phoenix, or a library such as Plug or Phoenix LiveView. Shoddy must not
contain such a function, because each project that uses Shoddy then gets
Phoenix. These functions go into ShoddyPhoenix.

A Phoenix application already has Phoenix. Thus ShoddyPhoenix adds no other
package to it.

## The direction of the dependency

ShoddyPhoenix can have Shoddy as a dependency. Shoddy never has
ShoddyPhoenix as a dependency, because Shoddy must not get Phoenix.

## The same conventions

ShoddyPhoenix obeys
[the conventions of Shoddy](https://github.com/rellen/shoddy/blob/main/docs/reference/conventions.md).
A person who knows one library then knows the rules of the other. These are
two examples:

- The first argument of each function is the value that the function
  operates on, such as a `Plug.Conn` struct.
- `ShoddyPhoenix.ControlFlow.choose/1` uses the same rule of truthiness as
  `Shoddy.then_if/2`. Only `nil` and `false` are falsy.

## Phoenix LiveView is optional

`ShoddyPhoenix.ControlFlow` needs `Phoenix.Component`, which is part of
Phoenix LiveView. Some Phoenix applications do not use LiveView. An example
is an application that returns only JSON. Thus `phoenix_live_view` is an
optional dependency of ShoddyPhoenix.

Mix does not add an optional dependency of ShoddyPhoenix to the project of
a user. A project that lists `phoenix_live_view` gets
`ShoddyPhoenix.ControlFlow`, and Mix applies the version requirement of
ShoddyPhoenix to it. A project without `phoenix_live_view` can still compile
ShoddyPhoenix, but it does not get that module.

## The name choose

`cond` is the natural name for the component. But HEEx compiles `<.cond>`
into the capture `&cond/1`. `cond` is a special form, so the compiler
rejects that capture with the error "invalid arguments for cond".

The names `choose`, `when` and `otherwise`, and the attribute `test`, come
from XSLT. XSLT uses `xsl:choose`, `xsl:when` with the attribute `test`, and
`xsl:otherwise` for the same structure. The JSP Standard Tag Library uses
the same names. A reader who knows one of these languages knows the names.

## Why HEEx evaluates every test

`cond` is a special form. The compiler gives it the expressions of the
conditions, and `cond` evaluates them one at a time.

A function component receives values, not expressions. HEEx builds the
attributes of each slot in the template of the caller, as plain map values.
Then it calls `choose/1` with the list of slots. Thus each `test` already has
a value when `choose/1` starts. The component cannot delay a test, and it
cannot skip a test.

The body of a slot is different. HEEx puts each body into a function, and
the component calls only the function of the selected slot. Thus the bodies
are lazy.

This difference is the reason for the section "Evaluation order" in the
documentation of `choose/1`. That section gives the two guards for a test
that relies on an earlier test.

## No match renders nothing

`cond` raises `CondClauseError` when no condition is true. But a template
frequently shows a part only in some states, as the attribute `:if` does.
Thus `<.choose>` renders nothing when no test is truthy and there is no
`<:otherwise>` slot. To show a fallback, add an `<:otherwise>` slot.

## One otherwise slot at most

A slot declaration cannot limit the number of entries of a slot. Thus the
component counts the `<:otherwise>` slots when it renders, and it raises
`ArgumentError` for two or more. A render of each fallback would surprise
the reader, and a selection of one fallback would hide a mistake.

## No whitespace

The component selects the branch in plain Elixir. Each outcome returns one
small template that contains only the selected body. Thus `<.choose>` adds
no whitespace around the body. `Phoenix.Component.async_result/1` has the
same shape.
