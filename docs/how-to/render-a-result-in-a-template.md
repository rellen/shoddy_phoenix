# Render a result in a template

This guide shows the result of an operation in a HEEx template with
`ShoddyPhoenix.ControlFlow.result/1`. A result is `{:ok, value}`, `:ok`,
`{:error, reason}` or `:error`.

Import `ShoddyPhoenix.ControlFlow` in your application first.
[Replace a cond block in a template](replace-a-cond-block-in-a-template.md#import-the-component)
gives that step.

If the LiveView loads the data with `assign_async/3`, do not use this guide.
Use `Phoenix.Component.async_result/1` instead.

## Keep the result in an assign

Put the return value of the operation into an assign. Before the first
operation, the assign is `nil`:

```elixir
def mount(_params, _session, socket) do
  {:ok, assign(socket, :save, nil)}
end

def handle_event("save", %{"user" => params}, socket) do
  result = Accounts.update_user(socket.assigns.user, params)
  {:noreply, assign(socket, :save, result)}
end
```

## Render the result

Give `<.result>` the assign. Put `:if` on the component, because the value
`nil` is not a result:

```heex
<.result :if={@save} value={@save}>
  <:ok :let={user}>Saved {user.name}.</:ok>
  <:error :let={reason}><p class="error">{inspect(reason)}</p></:error>
</.result>
```

For `{:ok, user}`, `:let` binds `user`. For `{:error, reason}`, `:let` binds
`reason`.

## Render only one outcome

Give only the slot that you need. The component renders nothing for the
other outcome:

```heex
<.result :if={@save} value={@save}>
  <:error>The save failed.</:error>
</.result>
```

## Render a result with no value

Some functions return `:ok` or `:error` with no value. `File.write/2` is an
example. For such a result, `:let` binds `nil`. Give the slot no `:let`:

```heex
<.result :if={@export} value={@export}>
  <:ok>The file is ready.</:ok>
  <:error :let={reason}>The export failed: {inspect(reason)}</:error>
</.result>
```

## Examine the values that are not results

The component raises `FunctionClauseError` for a value that is not a result,
such as `{:ok, user, warnings}` or `nil`. If a function can return another
form, convert the value into a result in the LiveView, before you put it
into the assign.
