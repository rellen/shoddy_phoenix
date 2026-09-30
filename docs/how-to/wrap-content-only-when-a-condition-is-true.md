# Wrap content only when a condition is true

This guide removes duplicated content from a template. The template shows the
content inside a wrapper in one case, and with no wrapper in the other case.
The guide uses `ShoddyPhoenix.ControlFlow.wrap_if/1`.

Import `ShoddyPhoenix.ControlFlow` in your application first.
[Replace a cond block in a template](replace-a-cond-block-in-a-template.md#import-the-component)
gives that step.

## Find the duplicated content

This template shows the name of a user as a link when the user has a profile
page. The name and its markup occur two times:

```heex
<a :if={@user.profile_url} href={@user.profile_url}>
  <img src={@user.avatar_url} alt="" /> {@user.name}
</a>
<span :if={!@user.profile_url}>
  <img src={@user.avatar_url} alt="" /> {@user.name}
</span>
```

## Write the content one time

1. Replace the two branches with a `<.wrap_if>` component. The condition
   becomes the attribute `test`.
2. Put the content into the component one time.
3. Add a `<:wrapper>` slot with `:let={content}`. Write the wrapper element
   in the slot, and put `{render_slot(content)}` inside it.

```heex
<.wrap_if test={@user.profile_url}>
  <:wrapper :let={content}><a href={@user.profile_url}>{render_slot(content)}</a></:wrapper>
  <img src={@user.avatar_url} alt="" /> {@user.name}
</.wrap_if>
```

The `<span>` of the old template is not necessary. If your CSS needs it, put
the `<span>` around the whole component.

## Examine the wrapper

The component cannot examine the body of `<:wrapper>`. Examine it yourself:

- The body calls `render_slot(content)` one time. With no call, the content
  disappears, and no error occurs. With two calls, the page contains the
  content two times.
- The body is not self-closing. A self-closing `<:wrapper />` raises
  `ArgumentError`.

The body of `<:wrapper>` runs only when `test` is truthy. Thus the body can use
a value that is `nil` when `test` is falsy, such as `@user.profile_url` in the
example.

## Examine a change of the condition

When `test` changes, the content moves into the wrapper or out of it, and
LiveView sends the whole content again. Examine this change in a browser if
the content keeps a state in the browser. The focus of an input, the text in
an input, and an element with a hook are examples of such a state.

## Keep a plain attribute for some templates

If only an attribute differs, do not use `<.wrap_if>`. Give the attribute an
expression:

```heex
<a href={@path} class={@active? && "active"}>{@label}</a>
```
