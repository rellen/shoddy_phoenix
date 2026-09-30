# Show a message for an empty list

This guide shows a message in place of a list that has no items. It uses
`ShoddyPhoenix.ControlFlow.each/1` for a list in an assign. For a stream, and
for a long list that changes before its end, it uses `:for` and CSS.

Import `ShoddyPhoenix.ControlFlow` in your application first.
[Replace a cond block in a template](replace-a-cond-block-in-a-template.md#import-the-component)
gives that step.

## Select the method

| The items | The method |
| --- | --- |
| A list, a range or a map in an assign | `<.each>` with `<:empty>` |
| A long list that changes before its end | `:for` with `:key`, and `:if` |
| A stream | `:for` in the stream container, and the CSS rule `:only-child` |

`<.each>` tracks the items by their position. When you add or remove an item
before the end of the list, LiveView sends each later item again. A `:for`
with `:key` sends much less in that case.

## Use each for a list in an assign

Put the list into `items`, and the content for one item into the component.
`:let` binds the item. Put the message into the `<:empty>` slot:

```heex
<ul>
  <.each :let={user} items={@users}>
    <li>{user.name}</li>
    <:empty><li>No users.</li></:empty>
  </.each>
</ul>
```

If the assign can be `nil`, for example before the data loads, give an empty
list in its place. The component raises `Protocol.UndefinedError` for `nil`:

```heex
<.each :let={user} items={@users || []}>
```

For a map, `:let` binds a `{key, value}` tuple. Elixir does not define the
order of a map. If the order is important, sort the map into a list first.

## Use :for with :key for a long list that changes

Give each item a key with `:key`, and show the message with `:if`:

```heex
<ul>
  <li :for={user <- @users} :key={user.id}>{user.name}</li>
  <li :if={@users == []}>No users.</li>
</ul>
```

## Use CSS for a stream

LiveView does not keep the items of a stream on the server after it renders
them. Thus the server cannot know whether a stream is empty, and `<.each>`
raises `ArgumentError` for a stream.

Put the message into the stream container as its first child, with the class
`only:block hidden`. With Tailwind, the message then shows only when it is the
only child of the container:

```heex
<ul id="users" phx-update="stream">
  <li id="users-empty" class="only:block hidden">No users.</li>
  <li :for={{dom_id, user} <- @streams.users} id={dom_id}>{user.name}</li>
</ul>
```

Give the message a unique `id`. Without it, LiveView cannot track the message
in the stream container, and later patches repeat it. The section "Handling
the empty case" in the documentation of `Phoenix.LiveView.stream/4` tells
more.
