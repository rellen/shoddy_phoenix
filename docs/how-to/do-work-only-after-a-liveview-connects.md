# Do work only after a LiveView connects

This guide subscribes a LiveView to a PubSub topic only after the LiveView
connects. It also shows a placeholder in the HTTP response. It uses
`ShoddyPhoenix.LiveView.when_connected/2` and
`ShoddyPhoenix.LiveView.when_not_connected/2`.

When a browser requests the page of a LiveView over HTTP, the LiveView mounts
two times. The first mount has a socket that is not connected, and it
renders the HTML of the HTTP response. The second mount occurs after the
browser connects. The section "The two renders" of `ShoddyPhoenix.LiveView`
tells more.

## Alias the module

Add the alias to the function `live_view/0` of `lib/my_app_web.ex`. Then
each LiveView of the application has it:

```elixir
def live_view do
  quote do
    use Phoenix.LiveView

    alias ShoddyPhoenix.LiveView

    unquote(html_helpers())
  end
end
```

If a LiveComponent uses the module, add the same alias to the function
`live_component/0`.

## Subscribe to a topic

Subscribe first. Then read the state, and assign it:

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> LiveView.when_connected(&subscribe/1)
    |> assign(:messages, MyApp.Messages.list_recent())

  {:ok, socket}
end

def handle_info({:new_message, message}, socket) do
  {:noreply, update(socket, :messages, &put_message(&1, message))}
end

defp subscribe(socket) do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "messages")
  socket
end

defp put_message(messages, message) do
  [message | Enum.reject(messages, &(&1.id == message.id))]
end
```

The function of `when_connected/2` must return the socket.
`Phoenix.PubSub.subscribe/2` returns `:ok`, so `subscribe/1` returns the
socket after that call.

Do not change the order of the two steps. If the LiveView reads first, it
loses each change between the read and the subscription. It gets no message
for such a change, so the page shows the old state.

A message can also arrive for a change that the read already contains. A
change between the subscription and the read is in the state, and its message
also arrives. Thus write `handle_info/2` so that such a message changes
nothing. `put_message/2` replaces a message by its id, so the message does
not show two times.

The section "Subscribe before you read" of `ShoddyPhoenix.LiveView` gives
these rules. [The design of ShoddyPhoenix](../explanation/design.md) tells
why the library has no function that sets the order.

Do not move the `assign` into the function. The disconnected render also
renders the template, and it raises `KeyError` for an assign that does not
exist.

To start a timer, use the same pattern. Call
`:timer.send_interval(1000, :tick)` in the function, and handle `:tick` in
`handle_info/2`.

If several parts of the LiveView subscribe to one topic, use
`ShoddyPhoenix.LiveView.Subscriptions` in place of `Phoenix.PubSub.subscribe/2`.
The LiveView then has one subscription to the topic, and it receives each
message one time. That module also does nothing in the disconnected render.
[Build a widget with lifecycle hooks](build-a-widget-with-lifecycle-hooks.md)
shows it.

## Show a placeholder until the LiveView connects

Give the HTTP response another template with `Phoenix.LiveView.render_with/2`.
Then load the data only after the connection:

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> LiveView.when_not_connected(fn socket -> render_with(socket, &loading/1) end)
    |> LiveView.when_connected(&assign(&1, :rows, Reports.list_rows()))

  {:ok, socket}
end

defp loading(assigns) do
  ~H"""
  <p>Loading the report.</p>
  """
end
```

The HTTP response contains only the placeholder. The connected render uses
the template of the LiveView, so only that render needs `@rows`.

A live navigation causes no disconnected render. Thus the browser does not
show the placeholder after a live navigation.

If the data takes a long time to load, use `Phoenix.LiveView.assign_async/4`
in place of these two steps. The mount then does not wait for the data.

## Examine the two renders in a test

`Phoenix.LiveViewTest.live/2` does the two renders. To examine only the HTTP
response, use `Phoenix.ConnTest.get/3`:

```elixir
test "the HTTP response shows the placeholder", %{conn: conn} do
  assert conn |> get(~p"/report") |> html_response(200) =~ "Loading the report."
end

test "the connected render shows the report", %{conn: conn} do
  {:ok, _view, html} = live(conn, ~p"/report")
  refute html =~ "Loading the report."
end
```
