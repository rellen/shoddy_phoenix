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

## The names of the components

`cond` is the natural name for `choose/1`. But HEEx compiles `<.cond>` into
the capture `&cond/1`. `cond` is a special form, so the compiler rejects that
capture with the error "invalid arguments for cond".

The names `choose`, `when` and `otherwise`, and the attribute `test`, come
from XSLT. XSLT uses `xsl:choose`, `xsl:when` with the attribute `test`, and
`xsl:otherwise` for the same structure. The JSP Standard Tag Library uses
the same names. A reader who knows one of these languages knows the names.

`switch/1` has the name of the same structure in C and in JavaScript. A
component with the name `case` compiles, but a reader can confuse it with
the special form `case/2`, which matches patterns. `switch/1` compares
values only.

Some libraries of UI components also have a `switch/1` for a toggle. An
application that imports such a library can import only some components of
`ShoddyPhoenix.ControlFlow`, with the option `:only` of `import`.

Each component names its fallback `<:otherwise>`, and each component
accepts one of it at most. A reader then learns one word for one purpose.

## Why HEEx evaluates every test

`cond` is a special form. The compiler gives it the expressions of the
conditions, and `cond` evaluates them one at a time.

A function component receives values, not expressions. HEEx builds the
attributes of each slot in the template of the caller, as plain map values.
Then it calls `choose/1` with the list of slots. Thus each `test` already has
a value when `choose/1` starts. The component cannot delay the evaluation of
an expression, and it cannot skip it.

The body of a slot is different. HEEx puts each body into a function, and
the component calls only the function of the selected slot. Thus the bodies
are lazy.

This difference is the reason for the section "Evaluation order" in the
documentation of `choose/1`. That section gives three guards for a test that
relies on an earlier test.

## Lazy tests

A test can be a function of arity 0. HEEx still makes the function on each
render, but the component calls it only when no earlier test is truthy.
Thus a lazy test gives `choose/1` the order of `cond`, for one test.

`Shoddy.coalesce/2` has the same rule for a function of arity 0 in its list.
A person who knows that rule then knows the rule of `choose/1`.

LiveView tracks a change of an assign inside such a function, as it does for
a plain value. When the assign changes, LiveView renders the component again.

## Values that need no guard

`switch/1` compares one value with the value of each `<:case>`. A value of a
case is usually a literal, such as `:loading`. A literal is cheap, and it
never raises. Thus `switch/1` does not have the unsafe pattern of
`choose/1`.

`switch/1` compares with `===/2`, as `Shoddy.MapSets.toggle/2` and
`Shoddy.coalesce/2` do. Thus the integer `1` and the float `1.0` are two
different values.

`result/1` evaluates one value, and it selects the slot with a pattern. It
accepts the four forms of a result that `Shoddy.Result` accepts. For a value
that is not a result, it raises `FunctionClauseError`, as most functions of
`Shoddy.Result` do. Such a value is a defect in the program, and an error at
the place of the defect is easier to find.

## No match renders nothing

`cond` raises `CondClauseError` when no condition is true. But a template
frequently shows a part only in some states, as the attribute `:if` does.
Thus `choose/1` and `switch/1` render nothing when no branch matches and
there is no `<:otherwise>` slot. `result/1` renders nothing when the slot of
the result is absent. To show a fallback, add the slot.

A self-closing slot also renders nothing. A self-closing `<:when>` that
matches thus hides the part for one case, and it stops the search.

## One slot at most

A slot declaration cannot limit the number of entries of a slot. Thus each
component counts the entries of `<:otherwise>`, `<:ok>` and `<:error>` when it
renders, and it raises `ArgumentError` for two or more. A render of each
entry would surprise the reader, and a selection of one entry would hide a
mistake.

## No whitespace

Each component selects the branch in plain Elixir. Each outcome returns one
small template that contains only the selected body. Thus a component adds
no whitespace around the body. `Phoenix.Component.async_result/1` has the
same shape.
