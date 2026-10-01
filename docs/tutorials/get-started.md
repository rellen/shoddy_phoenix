# Get started with ShoddyPhoenix

In this tutorial, you write a script with a function component that greets a
user. The component uses `ShoddyPhoenix.ControlFlow.choose/1` to select one
of three branches. You see why each test of `<.choose>` must be safe, and you
write tests for the component.

You need Elixir 1.19 or a later version, and git. You do not need a Phoenix
application. The script gets its dependencies with `Mix.install/2`.

## Make the script

Make a new directory. In it, make the file `greeting.exs` with this code:

```elixir
Mix.install([
  {:phoenix_live_view, "~> 1.2"},
  {:shoddy_phoenix, github: "rellen/shoddy_phoenix"}
])
```

`Mix.install/2` gets Phoenix LiveView from Hex and ShoddyPhoenix from
GitHub, and it compiles them. Run the script:

```sh
elixir greeting.exs
```

The first run gets and compiles the dependencies, so it is slow.
`Mix.install/2` keeps the result, so the next runs are fast. The script prints
nothing yet.

## Write the component

Add this module to the end of the script:

<!-- tutorial: earlier version -->
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

`Phoenix.LiveViewTest.rendered_to_string/1` converts the result of a
component to a string. Add these lines to the end of the script. They call
the component with an admin and with a user who is not an admin:

```elixir
alias Phoenix.LiveViewTest

IO.puts(LiveViewTest.rendered_to_string(Greeting.greeting(%{user: %{name: "Ada", admin?: true}})))
IO.puts(LiveViewTest.rendered_to_string(Greeting.greeting(%{user: %{name: "Grace", admin?: false}})))
```

The script uses an alias, not an `import`. An `import` at the top level of
the script fails, because Elixir needs the module before `Mix.install/2` gets
it.

Run the script again:

```sh
elixir greeting.exs
```

The script prints two lines:

```text
<a href="/admin">Admin panel</a>
Hello, Grace
```

Now add a line that calls the component with no user:

```elixir
IO.puts(LiveViewTest.rendered_to_string(Greeting.greeting(%{user: nil})))
```

Run the script again. It prints the two lines, and then the third call raises
an error:

```text
** (BadMapError) expected a map, got:

    nil
```

The first test is truthy, but the component raises an error. HEEx evaluates
the `test` of every `<:when>` before `<.choose>` selects a branch. Thus the
second test, `@user.admin?`, also runs when `@user` is `nil`. A `cond` block
stops at the first true condition, but `<.choose>` does not.

## Make the test safe

Put a guard in the second test. The operator `&&` does not evaluate its right
side when its left side is `nil`. Replace the module `Greeting` with this
version:

<!-- tutorial: replaces the earlier version -->
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
      <:when test={@user && @user.admin?}><a href="/admin">Admin panel</a></:when>
      <:otherwise>Hello, {@user.name}</:otherwise>
    </.choose>
    """
  end
end
```

Only the second `<:when>` is different. Run the script again. It prints three
lines:

```text
<a href="/admin">Admin panel</a>
Hello, Grace
<a href="/sign-in">Sign in</a>
```

## Test the component

Add these tests to the end of the script:

```elixir
ExUnit.start()

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

`ExUnit.start/1` starts ExUnit. When the script ends, ExUnit runs the tests.
Inside a module, an `import` works, because Elixir compiles the module after
`Mix.install/2` runs.

Run the script again. The output ends with `3 tests, 0 failures`.

## Next steps

You made a component with `<.choose>`, you found an unsafe test, and you
made the test safe.

- [See the two renders of a LiveView](see-the-two-renders-of-a-liveview.md)
  is the next tutorial. It shows why a LiveView mounts two times, and it
  uses `ShoddyPhoenix.LiveView`.
- [Replace a cond block in a template](../how-to/replace-a-cond-block-in-a-template.md)
  gives the steps to change a template of an application. It also shows
  `<.switch>` and a lazy test.
- [Render a result in a template](../how-to/render-a-result-in-a-template.md)
  shows `<.result>`.
- [Wrap content only when a condition is true](../how-to/wrap-content-only-when-a-condition-is-true.md)
  and [Show a message for an empty list](../how-to/show-a-message-for-an-empty-list.md)
  show `<.wrap_if>` and `<.each>`.
- The page of `ShoddyPhoenix.ControlFlow` gives each rule of `choose/1`. Its
  section "Evaluation order" tells what a test must be.
- [The design of ShoddyPhoenix](../explanation/design.md) tells why the
  tests of `<.choose>` are eager.
