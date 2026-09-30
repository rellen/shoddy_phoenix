# Replace a cond block in a template

This guide changes a `<%= cond do %>` block in a HEEx template into a
`<.choose>` component. The component is `ShoddyPhoenix.ControlFlow.choose/1`.

## Import the component

Do this step one time for each application. Your project needs the
dependency `phoenix_live_view`, version 1.2 or a later version before 2.0.

Open `lib/my_app_web.ex`, and import `ShoddyPhoenix.ControlFlow` in the
function `html_helpers/0`, next to the core components:

```elixir
defp html_helpers do
  quote do
    import MyAppWeb.CoreComponents
    import ShoddyPhoenix.ControlFlow
    # The other imports and aliases of the application.
  end
end
```

Each LiveView and each HTML module of the application can then use
`<.choose>`.

## Change the block

This example starts with a block that shows a spinner, an error or the
results:

```heex
<%= cond do %>
  <% @status == :loading -> %>
    <.spinner />
  <% @error -> %>
    <p class="error">{@error}</p>
  <% true -> %>
    <.results rows={@rows} />
<% end %>
```

1. Replace `<%= cond do %>` and `<% end %>` with `<.choose>` and
   `</.choose>`.
2. Change each condition into a `<:when>` slot, and keep the order. The
   condition becomes the attribute `test`.
3. Change the clause `true ->` into an `<:otherwise>` slot.
4. If a body uses the value of its condition, bind that value with `:let`.
   In this example, the second body uses `@error`.

The result renders the same HTML:

```heex
<.choose>
  <:when test={@status == :loading}><.spinner /></:when>
  <:when :let={error} test={@error}><p class="error">{error}</p></:when>
  <:otherwise><.results rows={@rows} /></:otherwise>
</.choose>
```

If each condition compares one value with a constant, use `<.switch>`
instead. It needs no guard, because it evaluates the value one time. For
example, a block with the conditions `@status == :loading` and
`@status == :failed` becomes this component:

```heex
<.switch value={@status}>
  <:case value={:loading}><.spinner /></:case>
  <:case value={:failed}><p class="error">The search failed.</p></:case>
  <:otherwise><.results rows={@rows} /></:otherwise>
</.switch>
```

## Make each test safe

`cond` stops at the first true condition. `<.choose>` evaluates every test
on every render, before it selects a branch. Examine each test, and find a
test that relies on an earlier test.

In this block, the second condition relies on the first condition to catch a
`nil` user:

```heex
<%= cond do %>
  <% is_nil(@user) -> %>
    Sign in
  <% @user.admin? -> %>
    Admin panel
  <% true -> %>
    Home
<% end %>
```

In a `<.choose>`, the test `@user.admin?` raises `BadMapError` when `@user`
is `nil`. Add a guard to such a test. Use one of these three forms:

```heex
<:when test={@user && @user.admin?}>Admin panel</:when>
<:when :if={@user} test={@user.admin?}>Admin panel</:when>
<:when test={fn -> @user.admin? end}>Admin panel</:when>
```

The third form is a lazy test. `<.choose>` calls the function only when no
earlier test is truthy, as `cond` does.

Also examine the cost of each test. If a test is expensive, compute the
value in the LiveView, and put it into an assign. Then use that assign in the
test.

## Examine the case with no match

A `cond` block with no true clause raises `CondClauseError` when no
condition is true. A `<.choose>` with no `<:otherwise>` slot renders nothing
in that case.

If the old block had no true clause, examine whether the page must show
something when no condition is true. If it must, add an `<:otherwise>` slot.

## Keep case for patterns

`<.choose>` and `<.switch>` do not match patterns. For a result, such as
`{:ok, user}` or `{:error, reason}`, use `<.result>`.
[Render a result in a template](render-a-result-in-a-template.md) gives the
steps.

For another pattern, keep `case` in the template, or use a function
component with more than one clause.
