# Build a widget with lifecycle hooks

This guide builds a chat widget. A LiveView can show several instances of
the widget. Each instance shows the messages of one PubSub topic.

The widget keeps its state in an assign of the LiveView. It handles its own
events and messages with lifecycle hooks. A lifecycle hook is a function that
LiveView calls before a callback of the LiveView, such as `handle_event/3`.
`Phoenix.LiveView.attach_hook/4` tells more. The article
[Phoenix LiveView widgets with hooks](https://curiosum.com/blog/hooking-up-with-liveview-stateful-widgets-with-function-components)
of Curiosum describes this pattern.

The widget uses four parts of ShoddyPhoenix:

- `ShoddyPhoenix.LiveView.Subscriptions` subscribes the LiveView to the topic
  of each instance.
- `ShoddyPhoenix.LiveView.Widgets` sends the events of the widget to the
  widget.
- `ShoddyPhoenix.LiveView.put_hook/4` attaches the hook for the messages.
- `ShoddyPhoenix.LiveView.Events` checks the event names of the widget at
  the compile time.

## Put the state into a struct

Make a module for the widget. Each instance is a struct in an assign of the
LiveView. The key of the assign is the name of the instance:

```elixir
defmodule MyAppWeb.ChatWidget do
  use Phoenix.Component
  use ShoddyPhoenix.LiveView.Events, prefix: "chat"

  alias ShoddyPhoenix.LiveView
  alias ShoddyPhoenix.LiveView.Subscriptions
  alias ShoddyPhoenix.LiveView.Widgets

  @pubsub MyApp.PubSub

  defstruct [:key, :topic, messages: []]
```

The option `prefix: "chat"` gives the name of the widget to
`ShoddyPhoenix.LiveView.Events`. The sections below use it.

## Add an instance

Add a function that puts an instance into the socket:

```elixir
  def assign_widget(socket, key, topic) do
    socket
    |> assign(key, %__MODULE__{key: key, topic: topic})
    |> Subscriptions.subscribe(@pubsub, topic, key)
    |> Widgets.route_events(event_prefix(), &handle_event/3)
    |> LiveView.put_hook({__MODULE__, :info}, :handle_info, &handle_info/2)
  end
```

Each step prevents one problem:

- `Subscriptions.subscribe/4` records the key as an owner of the topic. Two
  instances on one topic give the LiveView one subscription, so each message
  arrives one time. The function does nothing in the disconnected render.
- `Widgets.route_events/3` sends each event with a name that starts with
  `"chat:"` to `handle_event/3` of the widget. The LiveView never receives
  these events.
  `event_prefix()` returns `"chat"`, so the name of the widget occurs one
  time only.
- `put_hook/4` attaches the hook for the messages. The second instance
  calls it again, and it replaces the hook with no error.
  `Phoenix.LiveView.attach_hook/4` raises in that case.

## Render an instance

Add a function component for one instance:

```elixir
  attr :state, __MODULE__, required: true

  def render(assigns) do
    ~H"""
    <section id={"chat-#{@state.key}"}>
      <ul>
        <li :for={message <- @state.messages}>{message}</li>
      </ul>
      <form phx-submit={event("send")}>
        <input type="hidden" name="instance" value={@state.key} />
        <label>Message <input type="text" name="message" /></label>
        <button>Send</button>
      </form>
    </section>
    """
  end
```

`event("send")` returns `"chat:send"`, so the name of each event starts with
`"chat:"`. The hidden input tells the event which instance sent it.

`event/1` also records the name `"send"`. If `handle_event/3` of the widget
has no clause for `"send"`, the compiler gives a warning at the line of the
form. Without `event/1`, a wrong name raises `FunctionClauseError` only when
the form sends the event.

## Handle the events

`Widgets.route_events/3` removes `"chat:"` from the name of the event. Thus
the handler receives `"send"`:

```elixir
  defp handle_event("send", %{"instance" => instance, "message" => message}, socket)
       when is_binary(message) do
    with {:ok, {_key, state}} <- Widgets.fetch_instance(socket, __MODULE__, instance),
         message when message != "" <- String.trim(message) do
      Phoenix.PubSub.broadcast(@pubsub, state.topic, {__MODULE__, state.topic, message})
    end

    {:noreply, socket}
  end

  defp handle_event("send", _params, socket), do: {:noreply, socket}
```

The client chooses each parameter, so do not trust the parameters:

- `Widgets.fetch_instance/3` returns `:error` for a wrong instance. Then the
  `with` does nothing. Do not convert the parameter into an atom.
- The guard `is_binary(message)` rejects a message that is not a string.
- The second clause accepts each other form of the event. Without it, an
  event with other parameters raises `FunctionClauseError`, and the
  LiveView crashes.

## Handle the messages

Each message arrives one time. Give it to each instance on its topic:

```elixir
  defp handle_info({__MODULE__, topic, message}, socket) do
    socket =
      for {key, %__MODULE__{topic: ^topic} = state} <- socket.assigns, reduce: socket do
        socket -> assign(socket, key, %{state | messages: state.messages ++ [message]})
      end

    {:halt, socket}
  end

  defp handle_info(_message, socket), do: {:cont, socket}
```

The hook halts each message with the tag `__MODULE__`, because it gave that
message to each instance. Thus the `handle_info/2` of the LiveView needs no
clause for it. The hook continues each other message, so the LiveView still
receives its own messages.

Another part of the LiveView can also need the messages of the widget. Then
return `{:cont, socket}` from the first clause, and give the `handle_info/2`
of the LiveView a clause for these messages.

## Remove an instance

Add a function that removes an instance:

```elixir
  def remove_widget(socket, key) do
    %__MODULE__{topic: topic} = socket.assigns[key]

    socket
    |> Subscriptions.unsubscribe(@pubsub, topic, key)
    |> assign(key, nil)
  end
end
```

`Subscriptions.unsubscribe/4` removes only this owner. Another instance on
the same topic still receives each message. The hooks stay, and they find no
instance with this key. To remove the hooks, call
`Widgets.unroute_events/2` and `Phoenix.LiveView.detach_hook/3`.

After the removal, the assign of the instance is `nil`. The function
component of the widget raises for `nil`, so render an instance only while it
exists:

```heex
<ChatWidget.render :if={@left_chat} state={@left_chat} />
```

## Use the widget in a LiveView

Add the instances in `mount/3`, and render each instance:

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> ChatWidget.assign_widget(:left_chat, "chat:lobby")
    |> ChatWidget.assign_widget(:right_chat, "chat:lobby")

  {:ok, socket}
end

def render(assigns) do
  ~H"""
  <ChatWidget.render state={@left_chat} />
  <ChatWidget.render state={@right_chat} />
  """
end
```

The LiveView needs no `handle_event/3` and no `handle_info/2` for the widget.
A message from one instance shows in each instance, one time.

## Examine the limits

- A `:handle_params` hook works only in a LiveView that the router mounted
  with `live/3`. This widget has no such hook, so it also works in a nested
  LiveView of `live_render/3`.
- The socket of a LiveComponent does not accept a `:handle_info` hook. Thus
  `assign_widget/3` needs the socket of the LiveView, not the socket of a
  LiveComponent.
- Each name of a widget belongs to one module. `Widgets.route_events/3`
  raises `ArgumentError` when another module asks for the name `"chat"`.
