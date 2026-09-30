# Get started with ShoddyPhoenix

In this tutorial, you make a small project with a function component that
greets a user. The component uses `ShoddyPhoenix.ControlFlow.choose/1` to
select one of three branches. You see why each test of `<.choose>` must be
safe, and you write tests for the component.

You need Elixir 1.19 or a later version. You do not need a Phoenix
application. The project uses only Phoenix LiveView and ShoddyPhoenix.

## Make the project

Make a new project:

```sh
mix new greeting
cd greeting
```

Open `mix.exs`, and add Phoenix LiveView and ShoddyPhoenix to the list of
dependencies:

```elixir
defp deps do
  [
    {:phoenix_live_view, "~> 1.2"},
    {:shoddy_phoenix, github: "rellen/shoddy_phoenix"}
  ]
end
```

Get the dependencies:

```sh
mix deps.get
```

## Write the component

Replace the contents of `lib/greeting.ex` with this module:

```elixir
defmodule Greeting do
  @moduledoc """
  Renders a greeting for the user who is signed in.
  """

  use Phoenix.Component

  import ShoddyPhoenix.ControlFlow

  attr :user, :map, required: true

  def greeting(assigns) do
    ~H"""
    <.choose>
      <:when test={is_nil(@user)}><a href="/sign-in">Sign in</a></:when>
      <:when test={@user.admin?}><a href="/admin">Admin panel</a></:when>
      <:otherwise>Hello, {@user.name}</:otherwise>
    </.choose>
    """
  end
end
```

`<.choose>` renders the first `<:when>` with a truthy `test`. A truthy value
is a value that is not `nil` and not `false`. If no test is truthy,
`<.choose>` renders `<:otherwise>`.

## Try the component

Start IEx with the project:

```sh
iex -S mix
```

`Phoenix.LiveViewTest.rendered_to_string/1` converts the result of a
component to a string. Call the component with an admin and with a user who
is not an admin:

```elixir
iex> import Phoenix.LiveViewTest
Phoenix.LiveViewTest
iex> Greeting.greeting(%{user: %{name: "Ada", admin?: true}}) |> rendered_to_string()
"<a href=\"/admin\">Admin panel</a>"
iex> Greeting.greeting(%{user: %{name: "Grace", admin?: false}}) |> rendered_to_string()
"Hello, Grace"
```

Now call the component with no user:

```elixir
iex> Greeting.greeting(%{user: nil}) |> rendered_to_string()
** (BadMapError) expected a map, got:

    nil
```

The first test is truthy, but the component raises an error. HEEx evaluates
the `test` of every `<:when>` before `<.choose>` selects a branch. Thus the
second test, `@user.admin?`, also runs when `@user` is `nil`. A `cond` block
stops at the first true condition, but `<.choose>` does not.

## Make the test safe

Put a guard in the second test. The operator `&&` does not evaluate its right
side when its left side is `nil`:

```heex
<:when test={@user && @user.admin?}><a href="/admin">Admin panel</a></:when>
```

Compile the change in IEx, and call the component again:

```elixir
iex> recompile()
Compiling 1 file (.ex)
Generated greeting app
:ok
iex> Greeting.greeting(%{user: nil}) |> rendered_to_string()
"<a href=\"/sign-in\">Sign in</a>"
```

Stop IEx with Ctrl+C two times.

## Test the component

`mix new` made a test for a function that the module no longer has. Replace
the contents of `test/greeting_test.exs` with these tests:

```elixir
defmodule GreetingTest do
  use ExUnit.Case

  import Phoenix.LiveViewTest

  test "greeting/1 asks a visitor to sign in" do
    html = rendered_to_string(Greeting.greeting(%{user: nil}))
    assert html == ~s(<a href="/sign-in">Sign in</a>)
  end

  test "greeting/1 shows the admin panel to an admin" do
    user = %{name: "Ada", admin?: true}
    html = rendered_to_string(Greeting.greeting(%{user: user}))
    assert html == ~s(<a href="/admin">Admin panel</a>)
  end

  test "greeting/1 greets a user by name" do
    user = %{name: "Grace", admin?: false}
    assert rendered_to_string(Greeting.greeting(%{user: user})) == "Hello, Grace"
  end
end
```

Run the tests:

```sh
mix test
```

The output shows `3 tests, 0 failures`.

## Next steps

You made a component with `<.choose>`, you found an unsafe test, and you
made the test safe.

- [Replace a cond block in a template](../how-to/replace-a-cond-block-in-a-template.md)
  gives the steps to change a template of an application. It also shows
  `<.switch>` and a lazy test.
- [Render a result in a template](../how-to/render-a-result-in-a-template.md)
  shows `<.result>`.
- The page of `ShoddyPhoenix.ControlFlow` gives each rule of `choose/1`. Its
  section "Evaluation order" tells what a test must be.
- [The design of ShoddyPhoenix](../explanation/design.md) tells why the
  tests of `<.choose>` are eager.
