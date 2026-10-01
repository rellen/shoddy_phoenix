# Catch mistakes at compile time

LiveView finds many mistakes only at the run time. A wrong event name, a
wrong assign field or a wrong message makes a LiveView crash when a user
clicks or a message arrives. This guide gives the steps that make the
compiler find these mistakes.

Each section is one step, and you can do each step alone. The steps need
Elixir 1.19, because its type checker gives some of the warnings.
The tutorial
[Find mistakes before a LiveView runs](../tutorials/find-mistakes-before-a-liveview-runs.md)
shows the steps for the event names and for the state.

## Make a warning stop the compile

Most of the steps below give a warning, not an error. A warning does not
stop the compile. To make each warning stop it, run this command, for
example in your workflow:

```sh
mix compile --warnings-as-errors
```

Mix shows the warnings of a file again, also when it does not compile that
file again. Thus the command also fails after an earlier compile with the
same warning.

An application from `mix phx.new` 1.8.15 has the alias `precommit`, and that
alias runs `compile --warnings-as-errors`. The alias of `mix phx.new` 1.8.1
has `--warning-as-errors`, with no "s" after "warning". Mix ignores that
option, so the alias does not stop for a warning. Examine the alias in
`mix.exs`, and correct it if necessary.

## Name each event with event/1

`ShoddyPhoenix.LiveView.Events` compares the event names of a template with
the clauses of `handle_event/3`.

1. In `lib/my_app_web.ex`, add the `use` to `live_view/0` and to
   `live_component/0`:

   ```elixir
   def live_view do
     quote do
       use Phoenix.LiveView
       use ShoddyPhoenix.LiveView.Events

       unquote(html_helpers())
     end
   end

   def live_component do
     quote do
       use Phoenix.LiveComponent
       use ShoddyPhoenix.LiveView.Events

       unquote(html_helpers())
     end
   end
   ```

   A module that does not call `event/1` gets no warning from the `use`.

2. In each template, write the name of each event with `event/1`:

   ```heex
   <button phx-click={event("save")}>Save</button>
   <form phx-submit={event("send")} phx-change={event("validate")}>
   <button phx-click={JS.push(event("delete"))}>Delete</button>
   ```

3. Compile the application. For each name with no clause of
   `handle_event/3`, the compiler gives a warning at the line of the name.
   Correct the name, or add the clause.

The check does not see each name. For example, it does not see an event that
JavaScript sends. The page of `ShoddyPhoenix.LiveView.Events` gives the
limits.

For the events of a widget, use the option `:prefix`.
[Build a widget with lifecycle hooks](build-a-widget-with-lifecycle-hooks.md)
shows it.

## Put the state of a LiveView into a struct

The type checker of Elixir knows the fields of a struct. It does not know
the type of an assign. Put the state into a struct, and tell the type checker
where the struct is.

1. Make a struct for the state:

   ```elixir
   defmodule MyAppWeb.CounterLive.State do
     defstruct count: 0, step: 1
   end
   ```

2. Assign the struct in `mount/3`:

   ```elixir
   alias MyAppWeb.CounterLive.State

   def mount(_params, _session, socket) do
     {:ok, assign(socket, :state, %State{})}
   end
   ```

3. Put a pattern for the struct into the head of `render/1`:

   ```elixir
   def render(%{state: %State{}} = assigns) do
     ~H"""
     <p>Count: {@state.count}</p>
     """
   end
   ```

   The type checker then gives a warning for a wrong field, such as
   `{@state.cout}`.

4. In each handler, match the struct before you use it:

   ```elixir
   def handle_event("add", _params, socket) do
     %State{} = state = socket.assigns.state
     {:noreply, assign(socket, :state, %{state | count: state.count + state.step})}
   end
   ```

   The type checker then gives a warning for a wrong field, such as
   `state.stepp` or `%{state | cout: 1}`.

Without the pattern of step 3, the template has no check. A wrong field then
raises `KeyError` when the LiveView renders.

A LiveView with its template in a separate `.heex` file has no `render/1` in
its module. Thus it has no head for the pattern. Move the template into
`render/1`, or into a function component as below.

For a function component, declare the attribute with the struct as its type,
and make it required:

```elixir
attr :state, State, required: true

def counter(assigns) do
  ~H"""
  <p>Count: {@state.count}</p>
  """
end
```

For a required attribute with a struct type, LiveView puts the pattern into
the head of the function. An attribute that is not required gets no pattern.

The struct does not make a render send more data. `assign/3` keeps the old
struct for the next render. LiveView then sends an expression such as
`{@state.count}` only when the field `count` changed.

## Put each message into a struct

A message in a tuple, such as `{:posted, text}`, has no check. If the sender
writes `{:psoted, text}`, no clause of `handle_info/2` matches the message.

1. Make a struct for each message:

   ```elixir
   defmodule MyApp.Chat.Posted do
     defstruct [:room, :text]
   end
   ```

2. Send the struct:

   ```elixir
   Phoenix.PubSub.broadcast(MyApp.PubSub, "room:lobby", %Posted{room: "lobby", text: text})
   ```

3. Match the struct in `handle_info/2`:

   ```elixir
   def handle_info(%Posted{text: text}, socket) do
     {:noreply, update(socket, :messages, &[text | &1])}
   end
   ```

A wrong name of a struct, or a wrong field of a struct, is a compile error.
For example, `%Posted{txt: text}` stops the compile with the error
`unknown key :txt for struct MyApp.Chat.Posted`.

## Give the values of an attribute

A function component can give the permitted values of an attribute:

```elixir
attr :size, :atom, values: [:small, :large], default: :small
slot :inner_block, required: true

def badge(assigns) do
  ~H"""
  <span class={@size}>{render_slot(@inner_block)}</span>
  """
end
```

For `<.badge size={:medium}>New</.badge>`, LiveView gives a warning at the
compile time. It also gives a warning for a literal of the wrong type, for
example a string for an attribute of the type `:integer`.

LiveView examines only a literal value. For `<.badge size={@size}>New</.badge>`,
it gives no warning.
