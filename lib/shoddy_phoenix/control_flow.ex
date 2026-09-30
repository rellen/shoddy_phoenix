# This module needs Phoenix.Component, which is part of the optional
# dependency phoenix_live_view. Without that dependency, this file defines no
# module.
if Code.ensure_loaded?(Phoenix.Component) do
  defmodule ShoddyPhoenix.ControlFlow do
    @moduledoc """
    Function components for control flow in HEEx templates.

    `choose/1` renders one of several branches. It gives a template a readable
    alternative to a `<%= cond do %>` block:

    ```heex
    <.choose>
      <:when test={@status == :loading}><.spinner /></:when>
      <:when :let={error} test={@error}><p class="error">{error}</p></:when>
      <:otherwise><.results rows={@rows} /></:otherwise>
    </.choose>
    ```

    Tests are eager, and bodies are lazy. HEEx evaluates the `test` of each
    `<:when>` on each render, before `choose/1` selects a branch. Only the body
    of the selected branch runs.
    [The evaluation order](#choose/1-evaluation-order) tells how to write a
    test that is safe.

    ## Usage

    This module exists only if your project has the dependency
    `phoenix_live_view`, version 1.2 or a later version before 2.0.

    Import the module where your application imports its core components. In
    an application that `mix phx.new` made, that place is the function
    `html_helpers/0` in `lib/my_app_web.ex`:

    ```elixir
    defp html_helpers do
      quote do
        import MyAppWeb.CoreComponents
        import ShoddyPhoenix.ControlFlow
        # The other imports and aliases of the application.
      end
    end
    ```
    """

    use Phoenix.Component

    alias Phoenix.LiveView.Rendered

    @doc """
    Renders the first `<:when>` slot with a truthy `test`.

    A truthy value is a value that is not `nil` and not `false`. Thus `0`, `""`,
    `[]` and `%{}` are truthy.

    The component examines the `<:when>` slots in source order. It renders the
    first slot with a truthy `test`. The value of `test` is the argument of
    that slot, so `:let` binds it.

    If no `<:when>` slot matches, the component renders the `<:otherwise>`
    slot. If there is no `<:otherwise>` slot, it renders nothing. In the same
    case, `cond` raises `CondClauseError`.

    The component raises `ArgumentError` if it gets more than one
    `<:otherwise>` slot.

    ## Examples

    This template shows a spinner, an error or the results:

    ```heex
    <.choose>
      <:when test={@status == :loading}><.spinner /></:when>
      <:when :let={error} test={@error}><p class="error">{error}</p></:when>
      <:otherwise><.results rows={@rows} /></:otherwise>
    </.choose>
    ```

    In the second slot, `:let` binds `error` to the value of `@error`.

    A self-closing `<:when>` renders nothing when it matches, and it stops the
    search. This template shows nothing for a hidden panel, also when `@error`
    is truthy:

    ```heex
    <.choose>
      <:when test={@hidden?} />
      <:when :let={error} test={@error}><p class="error">{error}</p></:when>
      <:otherwise><.results rows={@rows} /></:otherwise>
    </.choose>
    ```

    `:if` and `:for` work on `<:when>`. The slots that `:for` makes keep the
    order of the list:

    ```heex
    <.choose>
      <:when :for={rule <- @rules} test={rule.matches?}>{rule.message}</:when>
      <:otherwise>No rule matches.</:otherwise>
    </.choose>
    ```

    ## Evaluation order

    > #### Every test is evaluated {: .warning}
    >
    > HEEx evaluates the `test` of every `<:when>` on every render, before
    > `choose/1` runs. A test runs also when an earlier test is truthy.

    Tests are eager. HEEx builds the attributes of each slot as plain map
    values in the template of the caller. That happens before `choose/1` runs,
    so a function component cannot change it.

    Slot bodies are lazy. `choose/1` renders only the body of the selected
    slot, and the other bodies do not run.

    `cond` is lazy in its conditions and in its bodies. It evaluates one
    condition at a time, and it stops at the first true condition. Thus
    `<.choose>` and `cond` behave differently when a test depends on an
    earlier test.

    ### The unsafe pattern

    In this template, the second test relies on the first test to catch a
    `nil` user:

    ```heex
    <.choose>
      <:when test={is_nil(@user)}>Sign in</:when>
      <:when test={@user.admin?}>Admin panel</:when>
      <:otherwise>Home</:otherwise>
    </.choose>
    ```

    When `@user` is `nil`, the second test raises `BadMapError`. A `cond` with
    the same conditions returns the first branch, and it does not raise.

    ### Two guards

    Put a guard in the test. The operator `&&` does not evaluate its right
    side when its left side is falsy:

    ```heex
    <:when test={@user && @user.admin?}>Admin panel</:when>
    ```

    This form is correct. It is not a pattern to avoid.

    Or put a guard on the slot with `:if`. When the `:if` expression is falsy,
    HEEx removes the whole slot, and it does not evaluate the `test` of that
    slot:

    ```heex
    <:when :if={@user} test={@user.admin?}>Admin panel</:when>
    ```

    HEEx still evaluates the `:if` expression of each slot on each render.

    ### What a test must be

    A test must be cheap and total, and it must have no side effects. A total
    expression returns a value for each input, and it never raises. A
    comparison of assigns, such as `@status == :loading`, behaves the same as
    in `cond`.

    Put expensive work in the LiveView, as an assign or as an Ash calculation.
    Do not put it in a test.

    ### When to use something else

    Use `case` or `cond` in the template, or a function component with more
    than one clause, in these cases:

    - One branch depends on another branch.
    - A branch needs pattern matching.
    - A test is expensive.
    """
    slot :when,
      required: true,
      doc: "A branch. The component renders the first `<:when>` with a truthy `test`." do
      attr :test, :any,
        required: true,
        doc: """
        Evaluated eagerly, on every render. A truthy value selects this branch,
        and the value becomes the argument of the slot.
        """
    end

    slot :otherwise, doc: "The branch that renders when no `<:when>` matches. Give one at most."

    @spec choose(map()) :: Rendered.t()
    def choose(%{otherwise: [_, _ | _] = otherwise}) do
      raise ArgumentError,
            "<.choose> accepts one <:otherwise> slot at most. It received #{length(otherwise)}."
    end

    # The component selects the branch in plain Elixir, and each outcome
    # returns one small template. Thus the component adds no whitespace, and
    # the change tracking of LiveView stays inside the body of each slot.
    # Phoenix.Component.async_result/1 has the same shape. `when` is a
    # reserved word, so the code cannot use `@when`.
    def choose(assigns) do
      case Enum.find(assigns.when, & &1.test) do
        nil ->
          ~H"{render_slot(@otherwise)}"

        %{inner_block: nil} ->
          ~H""

        entry ->
          assigns = assign(assigns, :entry, entry)
          ~H"{render_slot(@entry, @entry.test)}"
      end
    end
  end
end
