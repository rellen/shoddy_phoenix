# Find mistakes before a LiveView runs

In this tutorial, you write a script with two counters. Each counter has a
mistake in a name. Usually, LiveView finds such a mistake only when a user
clicks a button or opens the page. In this tutorial, the compiler finds each
mistake before the LiveView runs.

You use two tools:

- `ShoddyPhoenix.LiveView.Events` compares the event names of a template with
  the clauses of `handle_event/3`.
- A struct for the state of a LiveView lets the type checker of Elixir
  compare each field name of a template with the fields of the struct.

You need Elixir 1.19 or a later version, and git. The script uses
phoenix_playground, which runs a LiveView with no Phoenix application. If you
do not know `Mix.install/2`, do
[Get started with ShoddyPhoenix](get-started.md) first.

## Make the script

Make a new directory. In it, make the file `counter.exs` with this code:

```elixir
Mix.install([
  {:phoenix_playground, "~> 0.1.9"},
  {:shoddy_phoenix, github: "rellen/shoddy_phoenix"}
])

Logger.configure(level: :warning)
ExUnit.start()
```

The code does these steps:

- `Mix.install/2` gets phoenix_playground and ShoddyPhoenix. phoenix_playground
  also gets Phoenix LiveView.
- `Logger.configure/1` hides the log messages of Phoenix. The output then
  shows only the messages of the script.
- `ExUnit.start/1` starts ExUnit. When the script ends, ExUnit runs the
  tests of the script.

Run the script:

```sh
elixir counter.exs
```

The first run gets and compiles the dependencies, so it is slow. The output
ends with `0 tests, 0 failures`.

phoenix_playground has live reload, which loads a page again when its file
changes. On Linux, live reload needs `inotify-tools`. Without it, the script
logs an error about `inotify-tools`. The tests do not need live reload, so
you can ignore that error.

## Name the events with event/1

A template sends an event by its name, and `handle_event/3` receives the
event. Add this counter to the end of the script. The name `"decc"` of the
second button is a mistake:

<!-- tutorial: earlier version -->

```elixir
defmodule CounterLive do
  use Phoenix.LiveView
  use ShoddyPhoenix.LiveView.Events

  def mount(_params, _session, socket), do: {:ok, assign(socket, :count, 0)}

  def render(assigns) do
    ~H"""
    <p>Count: {@count}</p>
    <button phx-click={event("inc")}>+</button>
    <button phx-click={event("decc")}>-</button>
    """
  end

  def handle_event("inc", _params, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}
  def handle_event("dec", _params, socket), do: {:noreply, update(socket, :count, &(&1 - 1))}
end
```

`use ShoddyPhoenix.LiveView.Events` imports `event/1`. `event("inc")` returns
`"inc"`, and it records the name. After the compiler compiles the module,
`Events` compares each recorded name with the clauses of `handle_event/3`.

Run the script again. The output contains this warning:

```text
    warning: CounterLive has no clause of handle_event/3 for the event "decc"
    │
 19 │     <button phx-click={event("decc")}>-</button>
    │     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ counter.exs:19: (file)
```

The warning gives the module, the event and the line. Your line number can
be different. A warning does not stop the script, so the output ends with
`0 tests, 0 failures`.

Without `event/1`, the template has `phx-click="decc"`, and the compiler
gives no warning. Then a click on the button `-` sends `"decc"`. No clause of
`handle_event/3` matches that name, so the LiveView crashes with
`FunctionClauseError`.

## Correct the name

Replace `CounterLive` with this code. The second button now sends `"dec"`,
and a test clicks each button:

<!-- tutorial: replaces the earlier version -->

```elixir
defmodule CounterLive do
  use Phoenix.LiveView
  use ShoddyPhoenix.LiveView.Events

  def mount(_params, _session, socket), do: {:ok, assign(socket, :count, 0)}

  def render(assigns) do
    ~H"""
    <p>Count: {@count}</p>
    <button phx-click={event("inc")}>+</button>
    <button phx-click={event("dec")}>-</button>
    """
  end

  def handle_event("inc", _params, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}
  def handle_event("dec", _params, socket), do: {:noreply, update(socket, :count, &(&1 - 1))}
end

defmodule CounterLiveTest do
  use ExUnit.Case
  use PhoenixPlayground.Test, live: CounterLive

  test "the buttons change the count" do
    {:ok, view, _html} = live(build_conn(), "/")

    assert view |> element("button", "+") |> render_click() =~ "Count: 1"
    assert view |> element("button", "-") |> render_click() =~ "Count: 0"
  end
end
```

`use PhoenixPlayground.Test` gives the test the functions of
`Phoenix.LiveViewTest`. `live/2` requests the page of the LiveView, and then
it connects to the LiveView, as a browser does.

Run the script again. The output has no warning, and it ends with
`1 test, 0 failures`.

## Put the state into a struct

The second counter adds a step to the count. The state of the counter is a
struct with two fields. Add this code to the end of the script. The field
name `cout` in the template is a mistake:

<!-- tutorial: earlier version -->

```elixir
defmodule Counter do
  defstruct count: 0, step: 1
end

defmodule StepCounterLive do
  use Phoenix.LiveView
  use ShoddyPhoenix.LiveView.Events

  def mount(_params, _session, socket), do: {:ok, assign(socket, :counter, %Counter{step: 5})}

  def render(%{counter: %Counter{}} = assigns) do
    ~H"""
    <p>Count: {@counter.cout}</p>
    <button phx-click={event("add")}>Add {@counter.step}</button>
    """
  end

  def handle_event("add", _params, socket) do
    %Counter{} = counter = socket.assigns.counter
    {:noreply, assign(socket, :counter, %{counter | count: counter.count + counter.step})}
  end
end
```

The head of `render/1` has the pattern `%{counter: %Counter{}} = assigns`.
In a template, `@counter` is `assigns.counter`. Thus the pattern tells the
type checker that `@counter` is a `Counter` struct.

Run the script again. The output contains a warning that starts with these
lines:

```text
    warning: unknown key .cout in expression:

        assigns.counter.cout

    the given type does not have the given key:

        dynamic(%Counter{count: term(), step: term()})
```

The type checker knows the fields of `Counter`, so it finds the mistake. The
rest of the warning gives the line of the pattern and the line of the
mistake.

Without the pattern, the type checker does not know the type of `@counter`,
and it gives no warning. Then the first render raises `KeyError`.

The pattern `%Counter{} = counter` in `handle_event/3` does the same for the
handler. The type checker examines `counter.count`, `counter.step` and the
update `%{counter | count: ...}`.

## Correct the field name

Replace `Counter` and `StepCounterLive` with this code. The template now
reads `@counter.count`, and a test clicks the button:

<!-- tutorial: replaces the earlier version -->

```elixir
defmodule Counter do
  defstruct count: 0, step: 1
end

defmodule StepCounterLive do
  use Phoenix.LiveView
  use ShoddyPhoenix.LiveView.Events

  def mount(_params, _session, socket), do: {:ok, assign(socket, :counter, %Counter{step: 5})}

  def render(%{counter: %Counter{}} = assigns) do
    ~H"""
    <p>Count: {@counter.count}</p>
    <button phx-click={event("add")}>Add {@counter.step}</button>
    """
  end

  def handle_event("add", _params, socket) do
    %Counter{} = counter = socket.assigns.counter
    {:noreply, assign(socket, :counter, %{counter | count: counter.count + counter.step})}
  end
end

defmodule StepCounterLiveTest do
  use ExUnit.Case
  use PhoenixPlayground.Test, live: StepCounterLive

  test "the button adds the step to the count" do
    {:ok, view, html} = live(build_conn(), "/")

    assert html =~ "Count: 0"
    assert view |> element("button", "Add 5") |> render_click() =~ "Count: 5"
  end
end
```

Run the script again. The output has no warning, and it ends with
`2 tests, 0 failures`.

## Next steps

You made the compiler find a wrong event name and a wrong field name. Each
warning gave the line of the mistake before the LiveView ran.

- [Catch mistakes at compile time](../how-to/catch-mistakes-at-compile-time.md)
  gives the steps for an application. It also tells how a warning can stop
  the compile, and how to find a wrong message or a wrong attribute value.
- The page of `ShoddyPhoenix.LiveView.Events` tells which names the check
  sees, and which names it does not see.
- The section "Compile-time checks" of
  [The design of ShoddyPhoenix](../explanation/design.md) tells why the
  check is a warning and not an error.
