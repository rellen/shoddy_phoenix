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

`ShoddyPhoenix.ControlFlow` needs `Phoenix.Component`, and
`ShoddyPhoenix.LiveView` needs `Phoenix.LiveView`. Both are modules of
Phoenix LiveView. Some Phoenix applications do not use LiveView. An example
is an application that returns only JSON. Thus `phoenix_live_view` is an
optional dependency of ShoddyPhoenix.

Mix does not add an optional dependency of ShoddyPhoenix to the project of
a user. A project that lists `phoenix_live_view` gets the two modules, and
Mix applies the version requirement of ShoddyPhoenix to it. A project
without `phoenix_live_view` can still compile ShoddyPhoenix, but it does not
get these modules.

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

## The wrapper of wrap_if gets the content

A function component cannot put its content inside an element that the
caller writes. Thus `wrap_if/1` gives its content to the `<:wrapper>` slot as
the argument, and the wrapper calls `render_slot/1` with it. The template
then contains the content one time only.

This design has a cost. The component cannot examine the body of the
wrapper. If the wrapper does not render its argument, the content
disappears. If the wrapper renders it two times, the page contains it two
times. No error occurs in these cases, so the documentation of `wrap_if/1`
starts its section about the wrapper with a warning.

The body of the wrapper is a slot, so it is lazy. It runs only when `test` is
truthy. Thus the wrapper can use a value that exists only in that case, and
it needs no guard.

A self-closing slot renders nothing in each other component. A self-closing
`<:wrapper />` is different, because it hides the content with no error.
Thus `wrap_if/1` raises `ArgumentError` for it.

## A change of the wrap_if test

When `test` keeps its value, LiveView sends only the dynamic parts of the
content that changed. When `test` changes, the component returns a different
template, and LiveView sends the whole content again, with its static HTML.
A test measured this with LiveView 1.2.12.

The browser then gets new HTML for the content. A state in the browser, such
as the focus of an input, can depend on how LiveView patches that HTML. Thus
the documentation asks you to examine such a change in a browser, and it does
not promise a result.

## each and LiveView streams

`each/1` must know whether its items are empty before it renders them. An
Elixir stream, such as the result of `Stream.map/2`, is a plain lazy
enumerable, and `each/1` accepts it. A LiveView stream, such as
`@streams.users`, is different.

LiveView does not keep the items of a stream on the server after it renders
them. LiveView also lets only a `for` comprehension read a stream. Thus
`each/1` cannot know whether a stream is empty, and it raises
`ArgumentError` with a message that names the problem.

The documentation of `Phoenix.LiveView.stream/4` shows an empty state that
the browser selects with the CSS rule `:only-child`. That method needs no
information on the server.

The struct of a stream is private to LiveView, and it has no documentation.
`each/1` matches it with a pattern. If LiveView renames the struct, the
compilation fails, and the check cannot disappear with no warning.

## each tracks items by position

A `:for` without `:key` tracks each item by its position in the list.
`each/1` renders its items in a comprehension inside the component, and it
tracks them in the same way. The caller cannot give `:key` to `each/1`,
because LiveView accepts `:key` only together with `:for`.

These sizes come from a list of 50 short items with LiveView 1.2.12. Each
size is the number of bytes of the diff, printed with `inspect/2`:

| Change | `:for` with `:key` | `:for` without `:key` | `each/1` |
| --- | --- | --- | --- |
| The first render | 1338 | 1338 | 2235 |
| Add an item at the end | 51 | 51 | 109 |
| Change one item | 51 | 51 | 67 |
| Add an item at the start | 543 | 1281 | 1739 |
| Remove the first item | 510 | 1233 | 1633 |

`each/1` is thus a good choice for a short list, or for a list that changes
only at its end. For a long list that changes before its end, the
documentation recommends `:for` with `:key`.

## No match renders nothing

`cond` raises `CondClauseError` when no condition is true. But a template
frequently shows a part only in some states, as the attribute `:if` does.
Thus `choose/1` and `switch/1` render nothing when no branch matches and
there is no `<:otherwise>` slot. `result/1` renders nothing when the slot of
the result is absent, and `each/1` renders nothing for no items when there
is no `<:empty>` slot. To show a fallback, add the slot.

A self-closing slot also renders nothing, except for `<:wrapper />`. A
self-closing `<:when>` that matches thus hides the part for one case, and it
stops the search.

## One slot at most

A slot declaration cannot limit the number of entries of a slot. Thus each
component counts the entries of `<:otherwise>`, `<:ok>`, `<:error>`,
`<:wrapper>` and `<:empty>` when it renders, and it raises `ArgumentError` for
two or more. A render of each entry would surprise the reader, and a
selection of one entry would hide a mistake.

## No whitespace

Each component selects the branch in plain Elixir. Each outcome returns one
small template that contains only the selected body. Thus a component adds
no whitespace around the body. `Phoenix.Component.async_result/1` has the
same shape.

## The check of the socket

`Shoddy.then_if/3` can already apply a function when a predicate is truthy:

```elixir
Shoddy.then_if(socket, &Phoenix.LiveView.connected?/1, &subscribe/1)
```

`ShoddyPhoenix.LiveView.when_connected/2` returns the same result for a
function that returns a socket. It has two differences:

- Its name tells the condition. A reader does not need to read a predicate.
- It raises `ArgumentError` when the function does not return a socket.
  `Shoddy.then_if/3` accepts each value, so it cannot do this check.

The usual mistake is a function that ends with `Phoenix.PubSub.subscribe/2`.
That function returns `:ok`, not the socket. Without the check, the next
step of the pipeline or LiveView receives `:ok`. Its error names that step or
`mount/3`, and it does not name the function that returned `:ok`.

## Why when_not_connected exists

`when_not_connected/2` does not always run. A live navigation mounts a
LiveView with a connected socket only. Also, the connected process does not
get the assigns of the disconnected render. Thus the function can change
only the HTML of the HTTP response.

The documentation of `Phoenix.LiveView.render_with/2` shows such a change.
The HTTP response has a placeholder, and the connected render has the full
template. `when_not_connected/2` exists for that case, and its documentation
starts with a warning about the other cases.

## The name of the LiveView module

Shoddy gives some modules a name in the plural, such as `Shoddy.Maps`. Thus
an alias of the module does not hide a standard module, such as `Map`.

`ShoddyPhoenix.LiveView` ends with `LiveView`, as `Phoenix.LiveView` does,
because its functions operate on the same socket. Its alias `LiveView` hides
no standard module. If a module already has the alias `LiveView` for
`Phoenix.LiveView`, the option `:as` of `alias` gives `ShoddyPhoenix.LiveView`
another name.

## Tests with real LiveViews

The documentation of `ShoddyPhoenix.LiveView` describes the life cycle of a
LiveView, such as the two renders and the live navigation. These are facts
about LiveView, not about ShoddyPhoenix.

The tests render real LiveViews through a test endpoint. Thus a new version
of LiveView that changes such a fact makes a test fail, and the
documentation does not become wrong without a warning.
`Phoenix.LiveViewTest.live/2` needs the test dependency `lazy_html`, so
ShoddyPhoenix has it only in the test environment.

## The names of the modules

ShoddyPhoenix puts a module that operates on a LiveView or on its socket
under `ShoddyPhoenix.LiveView`. For example, `ShoddyPhoenix.LiveView.Events`
examines the code of a LiveView. ShoddyPhoenix puts a module for templates
at the top level.

A function component of `ShoddyPhoenix.ControlFlow` needs no socket. It
works in each HEEx template, also in a template that a controller renders.
Phoenix makes the same separation. `Phoenix.Component` is outside the module
`Phoenix.LiveView`, although both modules are in the package
`phoenix_live_view`.

## The owners of a topic

Phoenix.PubSub has no public function that tells whether a process has a
subscription. Thus `ShoddyPhoenix.LiveView.Subscriptions` keeps its own
record in the private data of the socket. `Phoenix.LiveView.put_private/3`
exists for such a record of a library.

The record contains owners, not a count. A count has two problems:

- An extra call of `subscribe` keeps a subscription that no part needs.
- An extra call of `unsubscribe` removes the subscription of another part.

With owners, a repeated call with the same owner changes nothing. A widget
that a LiveView adds two times thus causes no problem.

## The name of a widget

`ShoddyPhoenix.LiveView.Widgets.route_events/3` adds the colon to the name
of the widget. If the caller gave the full prefix, the prefix `"chat"` would
also own the event `"chatter:send"`.

One name belongs to one module. Each name has one hook, so a second module
with the same name would replace the hook of the first module. The events of
the first widget would then go to the wrong handler. Thus
`route_events/3` raises `ArgumentError`, and the mistake shows when the
LiveView mounts.

## Errors in the handler of a widget

`route_events/3` halts each event of the widget, also an event that the
handler cannot handle. The event never goes to the LiveView, because the
LiveView does not know the events of the widget.

`route_events/3` does not catch `FunctionClauseError`. The handler can call
another function that raises the same error, and a catch would hide that
error. A `handle_event/3` with no clause for an event also raises. Thus the
documentation asks for a clause for each event of a widget.

## The instance of an event

A client chooses each parameter of an event, and it can send each value.
`String.to_existing_atom/1` raises `ArgumentError` for a string that is not an
atom. A pattern match on the assign that the atom names can raise
`MatchError`, because the client can name an assign of another kind. Both
errors crash the LiveView.

`ShoddyPhoenix.LiveView.Widgets.fetch_instance/3` compares strings, and it
examines only the assigns that contain a struct of the widget. It makes no
atom, and it returns `:error` for each other value.

## The messages of the widget in the guide

The how-to guide "Build a widget with lifecycle hooks" halts each message
with the tag of the widget. The hook gives the message to each instance, so
no other code needs it. A LiveView with a `handle_info/2` that has no clause
for the message then does not crash. The hook continues each other message.

The guide also tells what to do when another part of the LiveView needs the
messages of the widget.

## Tutorials as scripts

Each tutorial is one script for `Mix.install/2`. The reader needs no Phoenix
application and no generator, such as `mix phx.new`. The tutorial contains
each line of the script, so the output of a generator cannot change the
lesson.

A lesson about a LiveView needs an endpoint, a router and a PubSub server.
phoenix_playground supplies the endpoint and the router, so the script shows
mostly the code of the lesson. The LiveView tutorial uses the test functions
of phoenix_playground. The reader then sees each problem in the output of a
test, with no browser.

A tutorial must work each time. Thus the job `tutorials` of the workflow
runs each tutorial against the code of the commit. A change that breaks a
tutorial makes the workflow fail. phoenix_playground is a dependency of the
tutorials only. ShoddyPhoenix does not depend on it.

## Compile-time checks

LiveView connects a template and its handlers with names. A template sends
an event by its name, and it reads an assign by its key. The compiler does
not compare these names, so a wrong name causes a crash at the run time.

`ShoddyPhoenix.LiveView.Events` compares the event names. The type checker
of Elixir 1.19 can compare the field names, but only for a struct. The guide
[Catch mistakes at compile time](../how-to/catch-mistakes-at-compile-time.md)
puts the state into a struct for that reason. A struct needs no code of
ShoddyPhoenix, so ShoddyPhoenix has no module for it.

### A warning, not an error

The check gives a warning, as the type checker and the `attr` declarations
of LiveView do. The compile continues, so one compile shows each mistake. A
project that needs an error uses `mix compile --warnings-as-errors`.

A wrong warning teaches a developer to ignore warnings. Thus the check warns
only when it is sure. A clause of `handle_event/3` with a variable as its
first argument can handle each name. Then the check gives no warning for that
module. The check also does not warn about a clause that no template uses,
because JavaScript can send that event.

### Literal names only

`event/1` accepts only a literal string. The value of a variable is known
only at the run time. If `event/1` accepted a variable, the check would skip
that name, and nothing would show the gap. The error at the compile time
shows it.

The option `:prefix` is also a literal string. With a module attribute,
Quokka, the formatter plugin of this repository, changed the `use` into code
that did not compile. A widget gives `event_prefix/0` to
`ShoddyPhoenix.LiveView.Widgets.route_events/3`, so the name occurs one time
only.

### The check runs after the compile

The check needs each call of `event/1` and each clause of `handle_event/3`.
A LiveView with its template in a separate `.heex` file gets `render/1` from
a `@before_compile` callback of LiveView. A `@before_compile` callback of
`Events` could run before that callback, and it would then not see the
template. That order depends on the order of the `use` lines.

Thus the check is an `@after_compile` callback. Elixir calls it after each
`@before_compile` callback, and `Module.get_definition/2` still returns the
clauses of `handle_event/3`. The order of the `use` lines then does not
matter.
