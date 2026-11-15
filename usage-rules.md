These rules give the correct use of each module of ShoddyPhoenix, and the
mistakes to avoid.

Read the documentation of a function before you use it. The source is in
`deps/shoddy_phoenix/lib`, and the guides are in `deps/shoddy_phoenix/docs`.
The site https://rellen.github.io/shoddy_phoenix/ has both.

### Setup

- ShoddyPhoenix is not on Hex. The dependency is
  `{:shoddy_phoenix, github: "rellen/shoddy_phoenix"}`.
- Each module below needs `phoenix_live_view`, version 1.2 or a later
  version before 2.0. Without that dependency, the modules do not exist.
- ShoddyPhoenix does not add Shoddy to a project. Do not call a function of
  `Shoddy` unless `mix.exs` has `{:shoddy, github: "rellen/shoddy"}`.
- Import `ShoddyPhoenix.ControlFlow` in the function `html_helpers/0` of
  `lib/my_app_web.ex`.
- Add `alias ShoddyPhoenix.LiveView` and `use ShoddyPhoenix.LiveView.Events`
  to the function `live_view/0` of that file. Add the same `use` to
  `live_component/0`.
- If the application has a component with the same name, such as a
  `switch/1`, import only the components that you use:
  `import ShoddyPhoenix.ControlFlow, only: [choose: 1, result: 1]`.

The examples below use the alias `LiveView` for `ShoddyPhoenix.LiveView`.

### Templates: ShoddyPhoenix.ControlFlow

| Component | What it renders |
| --- | --- |
| `ShoddyPhoenix.ControlFlow.choose/1` | The first `<:when>` with a truthy `test`, or `<:otherwise>` |
| `ShoddyPhoenix.ControlFlow.switch/1` | The first `<:case>` with a `value` that is equal to the `value` of the component, or `<:otherwise>` |
| `ShoddyPhoenix.ControlFlow.result/1` | `<:ok>` or `<:error>` for a result |
| `ShoddyPhoenix.ControlFlow.wrap_if/1` | Its content, inside `<:wrapper>` only when `test` is truthy |
| `ShoddyPhoenix.ControlFlow.each/1` | Its content for each item of `items`, or `<:empty>` |

These rules apply to each component:

- Only `nil` and `false` are falsy. `0`, `""` and `[]` are truthy.
- A component with no slot that matches renders nothing. It does not raise.
- A component adds no element and no whitespace. Write the list element or
  the table element around the component.

#### choose/1

HEEx evaluates the `test` of each `<:when>` on each render, also after a
truthy test. Do not write a test that is safe only after an earlier test:

```heex
<%!-- Wrong: the second test raises BadMapError for a nil user. --%>
<.choose>
  <:when test={is_nil(@user)}>Sign in</:when>
  <:when test={@user.admin?}>Admin panel</:when>
</.choose>
```

Each of these three forms is safe:

```heex
<:when test={@user && @user.admin?}>Admin panel</:when>
<:when :if={@user} test={@user.admin?}>Admin panel</:when>
<:when test={fn -> @user.admin? end}>Admin panel</:when>
```

- Keep each test cheap, and give it no side effects. Put expensive work into
  an assign.
- `:let` on a `<:when>` binds the value of its `test`.
- Use `switch/1` when each test compares one value with a constant.

#### switch/1

- The component compares with `===`. Thus `1` and `1.0` are different.
- Give each `<:case>` a literal value, such as `:loading`.

#### result/1

- The component accepts `{:ok, value}`, `:ok`, `{:error, reason}` and
  `:error`. `:let` binds the value or the reason.
- It raises `FunctionClauseError` for a value that is not a result, such as
  `nil`. For a result that can be `nil`, write `:if={@save}` on the
  component.
- Do not render a reason that is a tuple, a map or a struct. Render a message
  or a field of the reason.

#### wrap_if/1

The `<:wrapper>` must call `render_slot/1` one time with its `:let`
argument. If it does not, the content disappears, and no error occurs:

```heex
<.wrap_if test={@user.profile_url}>
  <:wrapper :let={content}><a href={@user.profile_url}>{render_slot(content)}</a></:wrapper>
  {@user.name}
</.wrap_if>
```

- A self-closing `<:wrapper />` raises `ArgumentError`.
- If only an attribute differs, such as a `class`, give that attribute an
  expression. Do not use `wrap_if/1`.

#### each/1

- Do not give a LiveView stream, such as `@streams.users`. The component
  raises `ArgumentError`.
- For a list that can be `nil`, write `items={@users || []}`.
- The component tracks the items by position, and it cannot take `:key`.
  For a long list that changes before its end, use `:for` with `:key`, and
  show the empty state with `:if`.

### Sockets: ShoddyPhoenix.LiveView

A page request mounts a LiveView two times. The first mount has a socket that
is not connected, and it runs in the process of the HTTP request. The second
mount has a connected socket. A live navigation causes only the second mount.

- `ShoddyPhoenix.LiveView.when_connected/2` applies a function to the socket
  only when the socket is connected. Use it for a subscription or a timer.
- The function must return the socket. Otherwise `when_connected/2` raises
  `ArgumentError`. `Phoenix.PubSub.subscribe/2` returns `:ok`, so return the
  socket after that call.
- Subscribe first. Then read the state that the topic changes, and assign it.
  The other order loses each change between the read and the subscription.
- Do not put an assign that the template needs into the function. The first
  mount does not call the function, and its render raises `KeyError`.

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> LiveView.when_connected(&subscribe/1)
    |> assign(:messages, MyApp.Messages.list_recent())

  {:ok, socket}
end

defp subscribe(socket) do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "messages")
  socket
end
```

- A message can arrive for a change that the read already contains. Write
  `handle_info/2` so that such a message changes nothing. For example,
  replace an item by its id, and do not add it a second time.
- `ShoddyPhoenix.LiveView.when_not_connected/2` applies a function only in
  the first mount. Use it only to change the HTML of the HTTP response, for
  example with `Phoenix.LiveView.render_with/2`. The second mount does not
  get its assigns, and a live navigation does not call it.
- `assign_async/4` and `start_async/4` start their task only for a connected
  socket. Do not put them into `when_connected/2`.
- `ShoddyPhoenix.LiveView.put_hook/4` attaches a lifecycle hook, and it
  replaces a hook with the same id and stage. Use it in code that can run two
  times, where `Phoenix.LiveView.attach_hook/4` raises.
- `put_hook/4` puts a replaced hook at the end of its stage. If a hook of
  that stage can halt, do not replace a hook after the first attachment.

### Subscriptions: ShoddyPhoenix.LiveView.Subscriptions

Use this module when more than one part of a LiveView needs one PubSub
topic. An owner is a term that names one part, such as the key of a widget:

```elixir
socket
|> Subscriptions.subscribe(MyApp.PubSub, "chat:lobby", :left_chat)
|> Subscriptions.subscribe(MyApp.PubSub, "chat:lobby", :right_chat)
```

- `ShoddyPhoenix.LiveView.Subscriptions.subscribe/4` adds an owner. The
  LiveView has one subscription to the topic, and it receives each message
  one time.
- `ShoddyPhoenix.LiveView.Subscriptions.unsubscribe/4` removes an owner. The
  LiveView unsubscribes with the last owner.
- Use this module for each subscription to that topic. Do not also call
  `Phoenix.PubSub.subscribe/2` or `Phoenix.PubSub.unsubscribe/2` for it.
- Both functions do nothing for a socket that is not connected. They need no
  `when_connected/2`.
- Do not give the socket of a LiveComponent. Both functions raise
  `ArgumentError` for it.

### Widgets: ShoddyPhoenix.LiveView.Widgets

A widget is a part of a LiveView with its own state, events and messages. It
keeps each instance as a struct in an assign of the LiveView. The guide is
`deps/shoddy_phoenix/docs/how-to/build-a-widget-with-lifecycle-hooks.md`.

- `ShoddyPhoenix.LiveView.Widgets.route_events/4` sends each event with a
  name that starts with the name of the widget and a colon to a handler. For
  the name `"chat"` and the event `"chat:send"`, the handler gets `"send"`.
- A name is not empty, it has no colon, and it belongs to one module.
- The handler returns `{:noreply, socket}` or `{:reply, map, socket}`.
- Give the option `:actions` with the actions of the widget. The hook then
  halts each other action, and a client cannot crash the LiveView with it.
- Do not give the handler a last clause that accepts each action. Such a
  clause stops the check of `ShoddyPhoenix.LiveView.Events`.
- For a widget with instances, use
  `ShoddyPhoenix.LiveView.Widgets.route_instance_events/5`. The handler gets
  `{key, struct}` for the instance that the parameter `"instance"` names.
  The hook halts an event that names no instance.
- Do not convert a parameter of an event into an atom with
  `String.to_existing_atom/1`. Use
  `ShoddyPhoenix.LiveView.Widgets.fetch_instance/3`, which returns
  `{:ok, {key, struct}}` or `:error`.
- `ShoddyPhoenix.LiveView.Widgets.unroute_events/2` stops the events of a
  name.

```elixir
def assign_widget(socket, key) do
  socket
  |> assign(key, %__MODULE__{key: key})
  |> Widgets.route_instance_events("chat", __MODULE__, &handle_event/4, actions: ["send"])
end

defp handle_event("send", %{"message" => message}, {key, chat}, socket) do
  {:noreply, assign(socket, key, %{chat | messages: [message | chat.messages]})}
end
```

### Event names: ShoddyPhoenix.LiveView.Events

After `use ShoddyPhoenix.LiveView.Events`, write each event name of a
template with the macro `ShoddyPhoenix.LiveView.Events.event/1`:

```heex
<button phx-click={event("save")}>Save</button>
<button phx-click={JS.push(event("delete"))}>Delete</button>
```

- The compiler gives a warning for a name with no clause of `handle_event/3`
  in the module. With `mix compile --warnings-as-errors`, the warning stops
  the compile.
- To remove a warning, correct the name or add the clause. Do not add a
  clause with a variable as its first argument. Such a clause stops the check
  for the whole module.
- `event/1` accepts only a literal string. It raises `ArgumentError` at the
  compile time for a variable.
- The check does not see a plain string, such as `phx-click="save"`. It also
  does not see an event that JavaScript sends.
- In a LiveComponent, use `event/1` only for an event with
  `phx-target={@myself}`. Another event goes to the LiveView.
- A function component in another module does not know the LiveView. Write
  the name with `event/1` in the LiveView, and give it to the component as
  an attribute.
- For a widget, write `use ShoddyPhoenix.LiveView.Events, prefix: "chat"`.
  Then `event("send")` returns `"chat:send"`, and the check looks for a
  clause for `"send"` in `handle_event/3` or `handle_event/4`.
- The prefix must be a literal string, not a module attribute. Give
  `ShoddyPhoenix.LiveView.Events.event_prefix/0` to `route_events/4`, so the
  name occurs one time.
