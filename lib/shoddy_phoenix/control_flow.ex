# This module needs Phoenix.Component, which is part of the optional
# dependency phoenix_live_view. Without that dependency, this file defines no
# module.
if Code.ensure_loaded?(Phoenix.Component) do
  defmodule ShoddyPhoenix.ControlFlow do
    @moduledoc """
    Function components for control flow in HEEx templates.

    - `choose/1` renders the first `<:when>` with a truthy `test`. It gives a
      template a readable alternative to a `<%= cond do %>` block.
    - `switch/1` renders the first `<:case>` whose `value` equals the value of
      the component.
    - `result/1` renders `<:ok>` or `<:error>` for a result, such as
      `{:ok, user}` or `{:error, reason}`.
    - `wrap_if/1` puts its content into a wrapper, such as a link, only when a
      test is truthy.
    - `each/1` renders its content for each item of a list, or an `<:empty>`
      slot for an empty list.

    ```heex
    <.choose>
      <:when test={@status == :loading}><.spinner /></:when>
      <:when :let={error} test={@error}><p class="error">{error}</p></:when>
      <:otherwise><.results rows={@rows} /></:otherwise>
    </.choose>
    ```

    Tests are eager, and bodies are lazy. HEEx evaluates the `test` of each
    `<:when>` on each render, before `choose/1` selects a branch. Only the body
    of the selected branch runs. A test that is a function of arity 0 is lazy.
    [The evaluation order](#choose/1-evaluation-order) tells how to write a
    test that is safe.

    In this documentation, the content of a component is the markup between its
    tags that is not in a named slot. The body of a slot is the markup between
    the tags of that slot.

    Each component adds no whitespace around the markup that it renders. The
    documentation of each component gives the mistakes to avoid. Read it before
    you use the component.

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

    If your application has another component with the same name, such as a
    `switch/1` for a toggle, import only the components that you use:

    ```elixir
    import ShoddyPhoenix.ControlFlow, only: [choose: 1, result: 1]
    ```
    """

    use Phoenix.Component

    alias Phoenix.LiveView.LiveStream
    alias Phoenix.LiveView.Rendered

    @doc """
    Renders the first `<:when>` slot with a truthy `test`.

    A truthy value is a value that is not `nil` and not `false`. Thus `0`, `""`,
    `[]` and `%{}` are truthy.

    The component examines the `<:when>` slots in source order. It renders the
    first slot with a truthy `test`. The value of `test` is the argument of
    that slot, so `:let` binds it.

    A `test` can be a function of arity 0. The component calls such a function
    only when no earlier test is truthy, and it uses the result as the value of
    the test. `Shoddy.coalesce/2` has the same rule. A function of another
    arity is a truthy value, and the component does not call it.

    If no `<:when>` slot matches, the component renders the `<:otherwise>`
    slot. If there is no `<:otherwise>` slot, it renders nothing. In the same
    case, `cond` raises `CondClauseError`.

    A self-closing slot renders nothing. The component raises `ArgumentError`
    if it gets more than one `<:otherwise>` slot.

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
    > `choose/1` runs. A test runs also when an earlier test is truthy. Only a
    > test that is a function of arity 0 is lazy.

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

    ### Three guards

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

    Or make the test lazy. HEEx makes the function on each render, but the
    component calls it only when no earlier test is truthy:

    ```heex
    <:when test={fn -> @user.admin? end}>Admin panel</:when>
    ```

    ### What a test must be

    A test that is not a function must be cheap and total, and it must have no
    side effects. A total expression returns a value for each input, and it
    never raises. A comparison of assigns, such as `@status == :loading`,
    behaves the same as in `cond`.

    A lazy test runs only when no earlier test is truthy. But it still runs on
    each render that reaches it. Put expensive work in the LiveView, as an
    assign or as an Ash calculation. Do not put it in a test.

    ### When to use something else

    - Use `switch/1` when each test compares one value with a constant.
    - Use `result/1` for `{:ok, value}` and `{:error, reason}`.
    - Use `case` in the template, or a function component with more than one
      clause, when a branch needs another pattern.
    """
    slot :when,
      required: true,
      doc: "A branch. The component renders the first `<:when>` with a truthy `test`." do
      attr :test, :any,
        required: true,
        doc: """
        Evaluated eagerly, on every render. A truthy value selects this branch,
        and the value becomes the argument of the slot. A function of arity 0
        is a lazy test, and the component calls it only when no earlier test is
        truthy.
        """
    end

    slot :otherwise,
      doc: "The branch that renders when no `<:when>` matches. Its argument is `nil`. Give one at most."

    @spec choose(map()) :: Rendered.t()
    def choose(assigns) do
      otherwise = at_most_one!(assigns, :choose, :otherwise)

      case Enum.find_value(assigns.when, &selected/1) do
        nil -> render_entry(assigns, otherwise, nil)
        {entry, value} -> render_entry(assigns, entry, value)
      end
    end

    @doc """
    Renders the first `<:case>` slot whose `value` equals the `value` of the
    component.

    The component compares the values with the strict equality operator
    `===/2`. Thus the integer `1` and the float `1.0` are two different values.
    The component examines the `<:case>` slots in source order, and it renders
    the first slot with an equal value.

    If no `<:case>` slot matches, the component renders the `<:otherwise>`
    slot. If there is no `<:otherwise>` slot, it renders nothing.

    A self-closing slot renders nothing. The component raises `ArgumentError`
    if it gets more than one `<:otherwise>` slot.

    The argument of a `<:case>` slot and of the `<:otherwise>` slot is `nil`.

    Use this component when each branch compares one value with a constant.
    HEEx evaluates the `value` of each `<:case>` on each render, as it does for
    the tests of `choose/1`. A literal value, such as `:loading`, is cheap and
    it never raises. Thus, when each `<:case>` has a literal value, `switch/1`
    does not have the unsafe pattern of `choose/1`. A value that reads an
    assign, such as `@user.role`, must be cheap and total, as a test of
    `choose/1` must be.

    ## Examples

    This template shows a spinner, a message or the results:

    ```heex
    <.switch value={@status}>
      <:case value={:loading}><.spinner /></:case>
      <:case value={:failed}><p class="error">The search failed.</p></:case>
      <:otherwise><.results rows={@rows} /></:otherwise>
    </.switch>
    ```

    `:if` and `:for` work on `<:case>`. This template shows the label of the
    current step:

    ```heex
    <.switch value={@step}>
      <:case :for={{step, label} <- @steps} value={step}>{label}</:case>
    </.switch>
    ```
    """
    attr :value, :any,
      required: true,
      doc: "The value that the component compares with the `value` of each `<:case>`."

    slot :case,
      required: true,
      doc: "A branch. The component renders the first `<:case>` with an equal `value`. Its argument is `nil`." do
      attr :value, :any,
        required: true,
        doc: """
        Evaluated eagerly, on every render. The component compares it with the
        `value` of the component by `===/2`.
        """
    end

    slot :otherwise,
      doc: "The branch that renders when no `<:case>` matches. Its argument is `nil`. Give one at most."

    @spec switch(map()) :: Rendered.t()
    def switch(assigns) do
      otherwise = at_most_one!(assigns, :switch, :otherwise)

      case Enum.find(assigns.case, &(&1.value === assigns.value)) do
        nil -> render_entry(assigns, otherwise, nil)
        entry -> render_entry(assigns, entry, nil)
      end
    end

    @doc """
    Renders `<:ok>` for an ok result, or `<:error>` for an error result.

    The component accepts the four forms of a result that `Shoddy.Result`
    accepts:

    | Form | Slot | Argument of the slot |
    | --- | --- | --- |
    | `{:ok, value}` | `<:ok>` | `value` |
    | `:ok` | `<:ok>` | `nil` |
    | `{:error, reason}` | `<:error>` | `reason` |
    | `:error` | `<:error>` | `nil` |

    Thus `:let` binds the value or the reason. If the slot of the result is
    absent, or if it is self-closing, the component renders nothing.

    The component raises `FunctionClauseError` for a value that is not a
    result, such as `nil`. For a result that can be `nil`, put `:if` on the
    component. The component raises `ArgumentError` if it gets more than one
    `<:ok>` slot or more than one `<:error>` slot.

    HEEx evaluates `value` one time for each render. Thus this component does
    not have the unsafe pattern of `choose/1`.

    ## Examples

    This template shows the result of a save:

    ```heex
    <.result value={@save}>
      <:ok :let={user}>Saved {user.name}.</:ok>
      <:error :let={reason}><p class="error">{reason}</p></:error>
    </.result>
    ```

    In this example, the reason is a string. HEEx renders a string, an atom or
    a number. For a tuple, a map or a struct, such as an `Ecto.Changeset`, it
    raises `Protocol.UndefinedError`. For such a reason, render a message, or
    render a field of the reason.

    This template shows a message only for an error:

    ```heex
    <.result :if={@save} value={@save}>
      <:error>The save failed.</:error>
    </.result>
    ```
    """
    attr :value, :any,
      required: true,
      doc: "The result: `{:ok, value}`, `:ok`, `{:error, reason}` or `:error`."

    slot :ok, doc: "The branch for an ok result. Its argument is the value, or `nil` for `:ok`."

    slot :error,
      doc: "The branch for an error result. Its argument is the reason, or `nil` for `:error`."

    @spec result(map()) :: Rendered.t()
    def result(%{value: {:ok, value}} = assigns), do: render_outcome(assigns, :ok, value)
    def result(%{value: :ok} = assigns), do: render_outcome(assigns, :ok, nil)
    def result(%{value: {:error, reason}} = assigns), do: render_outcome(assigns, :error, reason)
    def result(%{value: :error} = assigns), do: render_outcome(assigns, :error, nil)

    @doc """
    Puts the content into the `<:wrapper>` slot when `test` is truthy.

    When `test` is falsy, the component renders only its content. When `test`
    is truthy, it renders the `<:wrapper>` slot, and it gives the content to
    that slot as the argument. The wrapper puts the content where it calls
    `render_slot/1` with that argument. Thus the template contains the content
    one time only.

    A truthy value is a value that is not `nil` and not `false`. A `test` can
    be a function of arity 0, as in `choose/1`. The component then calls the
    function one time for each render.

    ## Examples

    This template shows the name of a user as a link to the profile of the
    user. For a user with no profile, it shows the name as plain text:

    ```heex
    <.wrap_if test={@user.profile_url}>
      <:wrapper :let={content}><a href={@user.profile_url}>{render_slot(content)}</a></:wrapper>
      {@user.name}
    </.wrap_if>
    ```

    The body of `<:wrapper>` runs only when `test` is truthy. Thus the body can
    use a value that exists only in that case. In this template, `@tooltip`
    can be `nil`:

    ```heex
    <.wrap_if test={@tooltip}>
      <:wrapper :let={content}><span title={@tooltip.text}>{render_slot(content)}</span></:wrapper>
      {@label}
    </.wrap_if>
    ```

    ## The wrapper and the content

    > #### Render the content one time {: .warning}
    >
    > The component does not examine the body of `<:wrapper>`. If the wrapper
    > does not call `render_slot/1` with its argument, the content disappears,
    > and no error occurs. If the wrapper calls it two times, the page contains
    > the content two times, and each `id` in the content occurs two times.

    The argument of `<:wrapper>` is a slot, not HTML. Give it only to
    `render_slot/1`.

    The component raises `ArgumentError` for a self-closing `<:wrapper />`,
    because such a wrapper hides the content. It also raises `ArgumentError`
    for more than one `<:wrapper>` slot. If `:if` removes the `<:wrapper>`, the
    component renders the content with no wrapper.

    ## Changes of the test

    While `test` keeps its value, LiveView sends only the parts of the content
    that changed. When `test` changes from falsy to truthy, or back, the
    content moves into the wrapper or out of it. LiveView then sends the whole
    content again, with its static HTML.

    If the content keeps a state in the browser, examine a change of `test` in
    a browser. The focus of an input, the text in an input, and an element
    with a hook are examples of such a state.

    ## When to use something else

    - If only an attribute differs, such as a `class`, give that attribute an
      expression. Do not use this component.
    - If the two branches differ in more than a wrapper, use `choose/1`.
    """
    attr :test, :any,
      required: true,
      doc: """
      Evaluated on every render. When it is truthy, the component puts the
      content into the wrapper. The component calls a function of arity 0 one
      time for each render.
      """

    slot :wrapper,
      required: true,
      doc: """
      The wrapper. Its argument is the content. Give the argument to
      `render_slot/1` one time.
      """

    slot :inner_block, required: true, doc: "The content."

    @spec wrap_if(map()) :: Rendered.t()
    def wrap_if(assigns) do
      case at_most_one!(assigns, :wrap_if, :wrapper) do
        %{inner_block: nil} ->
          raise ArgumentError,
                "<.wrap_if> needs a <:wrapper> slot with a body. A self-closing <:wrapper /> hides the content."

        wrapper ->
          if wrapper && evaluate(assigns.test) do
            render_entry(assigns, wrapper, assigns.inner_block)
          else
            ~H"{render_slot(@inner_block)}"
          end
      end
    end

    @doc """
    Renders the content for each item of `items`, or the `<:empty>` slot when
    `items` has no items.

    The argument of the content is the item, so `:let` binds it. The component
    converts `items` into a list with `Enum.to_list/1` one time for each
    render. It renders the items in the order of that list.

    If `items` has no items, the component renders the `<:empty>` slot. If
    there is no `<:empty>` slot, it renders nothing. A self-closing
    `<:empty />` also renders nothing. The component raises `ArgumentError`
    for more than one `<:empty>` slot.

    ## Examples

    This template shows a list of users, or a message for an empty list:

    ```heex
    <ul>
      <.each :let={user} items={@users}>
        <li>{user.name}</li>
        <:empty><li>No users.</li></:empty>
      </.each>
    </ul>
    ```

    ## The value of items

    `items` must be a finite enumerable, such as a list, a range or a map. A
    lazy enumerable, such as the result of `Stream.map/2`, also works. The
    component enumerates it one time for each render.

    For a map, the argument is a `{key, value}` tuple, so write
    `:let={{key, value}}`. Elixir does not define the order of the entries of a
    map. If the order is important, sort the map into a list first.

    For a value that is not enumerable, such as `nil`, the component raises
    `Protocol.UndefinedError`. For a list that can be `nil`, write
    `items={@users || []}`.

    > #### LiveView streams do not work {: .warning}
    >
    > The component raises `ArgumentError` for a LiveView stream, such as
    > `@streams.users`. LiveView does not keep the items of a stream on the
    > server after it renders them. Thus the component cannot know whether
    > the stream is empty.

    For the empty state of a LiveView stream, use the CSS rule of the section "Handling
    the empty case" in the documentation of `Phoenix.LiveView.stream/4`.

    ## Change tracking

    `each/1` tracks the items by their position in the list, as a `:for`
    without `:key` does. When you add an item at the end of the list, or
    change one item, LiveView sends only that item. When you add or remove an
    item before the end, LiveView sends each later item again. A `:for` with
    `:key` sends much less in that case. The caller cannot give `:key` to
    `each/1`, because LiveView accepts `:key` only together with `:for`.

    The first render of `each/1` is also larger than the first render of the
    same `:for`. The component renders each item as a separate slot.

    For a long list that changes before its end, use `:for` with `:key`, and
    show the empty state with `:if`:

    ```heex
    <ul>
      <li :for={user <- @users} :key={user.id}>{user.name}</li>
      <li :if={@users == []}>No users.</li>
    </ul>
    ```
    """
    attr :items, :any,
      required: true,
      doc: "A finite enumerable, such as a list. A LiveView stream is not permitted."

    slot :inner_block, required: true, doc: "The content for each item. Its argument is the item."

    slot :empty,
      doc: "The markup when `items` has no items. Its argument is `nil`. Give one at most."

    @spec each(map()) :: Rendered.t()
    # Phoenix.LiveView.LiveStream is a private struct of LiveView. If LiveView
    # renames it, this pattern fails to compile, so the check cannot disappear
    # with no warning.
    def each(%{items: %LiveStream{}}) do
      raise ArgumentError,
            "<.each> does not accept a stream. LiveView does not keep the items of a stream " <>
              "on the server, so <.each> cannot know whether the stream is empty."
    end

    def each(assigns) do
      empty = at_most_one!(assigns, :each, :empty)

      case Enum.to_list(assigns.items) do
        [] ->
          render_entry(assigns, empty, nil)

        list ->
          assigns = assign(assigns, :list, list)
          ~H"<%= for item <- @list do %>{render_slot(@inner_block, item)}<% end %>"
      end
    end

    defp render_outcome(assigns, slot, argument) do
      ok = at_most_one!(assigns, :result, :ok)
      error = at_most_one!(assigns, :result, :error)
      render_entry(assigns, if(slot == :ok, do: ok, else: error), argument)
    end

    defp selected(entry) do
      case evaluate(entry.test) do
        falsy when falsy in [nil, false] -> nil
        value -> {entry, value}
      end
    end

    defp evaluate(test) when is_function(test, 0), do: test.()
    defp evaluate(test), do: test

    defp at_most_one!(assigns, component, slot) do
      case Map.fetch!(assigns, slot) do
        [_, _ | _] = entries ->
          raise ArgumentError,
                "<.#{component}> accepts one <:#{slot}> slot at most. It received #{length(entries)}."

        entries ->
          List.first(entries)
      end
    end

    # Each outcome returns one small template. Thus a component adds no
    # whitespace, and the change tracking of LiveView stays inside the body of
    # each slot. Phoenix.Component.async_result/1 has the same shape. An
    # absent slot and a self-closing slot render nothing.
    defp render_entry(assigns, nil, _argument), do: ~H""
    defp render_entry(assigns, %{inner_block: nil}, _argument), do: ~H""

    defp render_entry(assigns, entry, argument) do
      assigns = assign(assigns, entry: entry, argument: argument)
      ~H"{render_slot(@entry, @argument)}"
    end
  end
end
