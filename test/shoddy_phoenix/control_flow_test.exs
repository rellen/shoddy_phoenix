defmodule ShoddyPhoenix.ControlFlowTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO, only: [with_io: 2]
  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import ShoddyPhoenix.ControlFlow

  alias Phoenix.LiveView.Diff
  alias Phoenix.LiveView.Lifecycle
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket
  alias ShoddyPhoenix.Test.Warnings

  # The type checker of Elixir can warn about a literal such as %{user: nil}
  # that a later expression uses as a map. This helper returns its argument,
  # and the type checker cannot see through it.
  defp opaque(value), do: Process.get({__MODULE__, :unset}, value)

  # This helper sends a message to the test process, and it returns its
  # argument. A test then knows which expressions of a template ran.
  defp mark(value) do
    send(self(), {:ran, value})
    value
  end

  # This helper raises when a template calls it. The type checker cannot see
  # that it always raises, so it does not warn about the templates that call it.
  defp crash!, do: opaque(nil) || raise("this body must not run")

  # These templates differ only in the kind of the test. The body does not use
  # an assign, so only the test decides whether the component changed.
  defp lazy_template(assigns), do: ~H"<.choose><:when test={fn -> @user end}>x</:when></.choose>"
  defp plain_template(assigns), do: ~H"<.choose><:when test={@user}>x</:when></.choose>"

  # These components stand in for the components of the examples in the docs.
  defp spinner(assigns), do: ~H"<span>Loading</span>"
  defp results(assigns), do: ~H"<ul>{length(@rows)} rows</ul>"

  # These templates show what LiveView sends to the browser. The first render
  # gives the fingerprints, and the second render gives the diff against them.
  # Phoenix.LiveView.Diff is a private module of LiveView, so a change of
  # LiveView can break this helper. Such a break tells that the docs about
  # change tracking need a new examination.
  defp second_diff(template, first_assigns, second_assigns, changed) do
    socket = %Socket{}
    first = template.(Map.put(first_assigns, :__changed__, nil))

    {first_diff, prints, components} =
      Diff.render(socket, first, Diff.new_fingerprints(), Diff.new_components())

    second = template.(Map.put(second_assigns, :__changed__, changed))
    {second_diff, _prints, _components} = Diff.render(socket, second, prints, components)
    {inspect(first_diff, limit: :infinity), inspect(second_diff, limit: :infinity)}
  end

  defp profile_link(assigns) do
    ~H"""
    <.wrap_if test={@url}><:wrapper :let={content}><a href={@url}>{render_slot(content)}</a></:wrapper><span>{@name}</span> static text</.wrap_if>
    """
  end

  defp list_with_each(assigns), do: ~H|<ul><.each :let={item} items={@items}><li>{item}</li></.each></ul>|
  defp list_with_key(assigns), do: ~H|<ul><li :for={item <- @items} :key={item}>{item}</li></ul>|

  describe "choose/1: selection" do
    test "renders the first slot with a truthy test, in source order" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={false}>a</:when>
          <:when test={true}>b</:when>
          <:when test={true}>c</:when>
          <:otherwise>d</:otherwise>
        </.choose>
        """)

      assert html == "b"
    end

    test "treats only nil and false as falsy" do
      for {value, expected} <- [
            {nil, "no"},
            {false, "no"},
            {0, "yes"},
            {"", "yes"},
            {[], "yes"},
            {%{}, "yes"}
          ] do
        assigns = %{value: value}

        html =
          rendered_to_string(~H"""
          <.choose>
            <:when test={@value}>yes</:when>
            <:otherwise>no</:otherwise>
          </.choose>
          """)

        assert html == expected, "expected #{expected} for #{inspect(value)}"
      end
    end

    test "renders each branch of the example in the docs" do
      for {assigns, expected} <- [
            {%{status: :loading, error: nil, rows: []}, "<span>Loading</span>"},
            {%{status: :done, error: "No network", rows: []}, ~s(<p class="error">No network</p>)},
            {%{status: :done, error: nil, rows: [1, 2]}, "<ul>2 rows</ul>"}
          ] do
        html =
          rendered_to_string(~H"""
          <.choose>
            <:when test={@status == :loading}><.spinner /></:when>
            <:when :let={error} test={@error}><p class="error">{error}</p></:when>
            <:otherwise><.results rows={@rows} /></:otherwise>
          </.choose>
          """)

        assert html == expected
      end
    end
  end

  describe "choose/1: fallbacks" do
    test "renders the otherwise slot when no test is truthy" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={nil}>a</:when>
          <:when test={false}>b</:when>
          <:otherwise>c</:otherwise>
        </.choose>
        """)

      assert html == "c"
    end

    test "renders nothing when no test is truthy and there is no otherwise slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={nil}>a</:when>
        </.choose>
        """)

      assert html == ""
    end

    test "differs from cond, which raises CondClauseError when no condition is true" do
      assert_raise CondClauseError, fn ->
        cond do
          opaque(nil) -> "a"
        end
      end
    end

    test "renders nothing for a self-closing slot that matches, and stops the search" do
      assigns = %{hidden?: true, error: "No network", rows: []}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={@hidden?} />
          <:when :let={error} test={@error}><p class="error">{error}</p></:when>
          <:otherwise><.results rows={@rows} /></:otherwise>
        </.choose>
        """)

      assert html == ""
    end

    test "raises ArgumentError for two otherwise slots" do
      assigns = %{}

      assert_raise ArgumentError, "<.choose> accepts one <:otherwise> slot at most. It received 2.", fn ->
        rendered_to_string(~H"""
        <.choose>
          <:when test={false}>a</:when>
          <:otherwise>b</:otherwise>
          <:otherwise>c</:otherwise>
        </.choose>
        """)
      end
    end

    test "renders nothing for a self-closing otherwise slot" do
      assigns = %{}

      assert rendered_to_string(~H"<.choose><:when test={false}>a</:when><:otherwise /></.choose>") == ""
    end

    test "gives the otherwise slot the argument nil" do
      assigns = %{}

      assert rendered_to_string(
               ~H"<.choose><:when test={false}>a</:when><:otherwise :let={arg}>{inspect(arg)}</:otherwise></.choose>"
             ) == "nil"

      assert rendered_to_string(
               ~H"<.switch value={1}><:case value={2}>a</:case><:otherwise :let={arg}>{inspect(arg)}</:otherwise></.switch>"
             ) == "nil"
    end
  end

  describe "choose/1: slot features" do
    test "binds the value of the test with :let" do
      assigns = %{value: 42}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when :let={value} test={@value}>{value}</:when>
        </.choose>
        """)

      assert html == "42"
    end

    test "keeps the source order for the slots that :for makes" do
      for {values, expected} <- [{[nil, "b", "c"], "b"}, {[nil, false], "d"}] do
        assigns = %{values: values}

        html =
          rendered_to_string(~H"""
          <.choose>
            <:when test={false}>a</:when>
            <:when :for={value <- @values} test={value}>{value}</:when>
            <:when test={true}>d</:when>
          </.choose>
          """)

        assert html == expected
      end
    end

    test "renders the rule example in the docs" do
      assigns = %{
        rules: [
          %{matches?: false, message: "Too short"},
          %{matches?: true, message: "No digit"},
          %{matches?: true, message: "No symbol"}
        ]
      }

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when :for={rule <- @rules} test={rule.matches?}>{rule.message}</:when>
          <:otherwise>No rule matches.</:otherwise>
        </.choose>
        """)

      assert html == "No digit"
    end

    test "removes a slot with a falsy :if" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when :if={false} test={true}>a</:when>
          <:when test={true}>b</:when>
        </.choose>
        """)

      assert html == "b"
    end

    test "nests inside a branch" do
      assigns = %{outer: true, inner: nil}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={@outer}>
            <.choose>
              <:when test={@inner}>a</:when>
              <:otherwise>b</:otherwise>
            </.choose>
          </:when>
          <:otherwise>c</:otherwise>
        </.choose>
        """)

      assert String.trim(html) == "b"
    end
  end

  describe "choose/1: lazy bodies" do
    test "runs only the body of the selected slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={false}>{mark(:first_body)}</:when>
          <:when test={true}>{mark(:second_body)}</:when>
          <:otherwise>{mark(:otherwise_body)}</:otherwise>
        </.choose>
        """)

      assert html == "second_body"
      assert_received {:ran, :second_body}
      refute_received {:ran, :first_body}
      refute_received {:ran, :otherwise_body}
    end

    test "does not run a body that would crash when another slot is selected" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={true}>ok</:when>
          <:when test={true}>{crash!()}</:when>
          <:otherwise>{crash!()}</:otherwise>
        </.choose>
        """)

      assert html == "ok"
    end
  end

  describe "choose/1: eager tests, as the section Evaluation order of the docs tells" do
    test "evaluates every test, also after an earlier test matched" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={mark(:first_test)}>a</:when>
          <:when test={mark(:second_test)}>b</:when>
        </.choose>
        """)

      assert html == "a"
      assert_received {:ran, :first_test}
      assert_received {:ran, :second_test}
    end

    test "proves the docs: an unguarded later test raises BadMapError, and cond does not" do
      assigns = %{user: opaque(nil)}

      assert_raise BadMapError, fn ->
        rendered_to_string(~H"""
        <.choose>
          <:when test={is_nil(@user)}>Sign in</:when>
          <:when test={@user.admin?}>Admin panel</:when>
          <:otherwise>Home</:otherwise>
        </.choose>
        """)
      end

      user = opaque(nil)

      branch =
        cond do
          is_nil(user) -> "Sign in"
          user.admin? -> "Admin panel"
          true -> "Home"
        end

      assert branch == "Sign in"
    end

    test "evaluates each :if expression, also after an earlier test matched" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={true}>a</:when>
          <:when :if={mark(:if_expression)} test={true}>b</:when>
        </.choose>
        """)

      assert html == "a"
      assert_received {:ran, :if_expression}
    end
  end

  describe "choose/1: the guards in the docs" do
    @users [
      {nil, "Sign in"},
      {%{admin?: true}, "Admin panel"},
      {%{admin?: false}, "Home"}
    ]

    test "a guard with && in the test prevents the error" do
      for {user, expected} <- @users do
        assigns = %{user: opaque(user)}

        html =
          rendered_to_string(~H"""
          <.choose>
            <:when test={is_nil(@user)}>Sign in</:when>
            <:when test={@user && @user.admin?}>Admin panel</:when>
            <:otherwise>Home</:otherwise>
          </.choose>
          """)

        assert html == expected
      end
    end

    test "a guard with :if on the slot prevents the error" do
      for {user, expected} <- @users do
        assigns = %{user: opaque(user)}

        html =
          rendered_to_string(~H"""
          <.choose>
            <:when test={is_nil(@user)}>Sign in</:when>
            <:when :if={@user} test={@user.admin?}>Admin panel</:when>
            <:otherwise>Home</:otherwise>
          </.choose>
          """)

        assert html == expected
      end
    end

    test "a lazy test prevents the error" do
      for {user, expected} <- @users do
        assigns = %{user: opaque(user)}

        html =
          rendered_to_string(~H"""
          <.choose>
            <:when test={is_nil(@user)}>Sign in</:when>
            <:when test={fn -> @user.admin? end}>Admin panel</:when>
            <:otherwise>Home</:otherwise>
          </.choose>
          """)

        assert html == expected
      end
    end
  end

  describe "choose/1: lazy tests" do
    test "calls a function of arity 0 only when no earlier test is truthy" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={fn -> mark(false) end}>a</:when>
          <:when test={fn -> mark(:second) end}>b</:when>
          <:when test={fn -> mark(:third) end}>c</:when>
        </.choose>
        """)

      assert html == "b"
      assert_received {:ran, false}
      assert_received {:ran, :second}
      refute_received {:ran, :third}
    end

    test "uses the result of the function as the argument of the slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when :let={value} test={fn -> 42 end}>{value}</:when>
        </.choose>
        """)

      assert html == "42"
    end

    test "treats a falsy result of the function as a falsy test" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when test={fn -> nil end}>a</:when>
          <:when test={fn -> false end}>b</:when>
          <:otherwise>c</:otherwise>
        </.choose>
        """)

      assert html == "c"
    end

    # The dynamic part of the template is nil when LiveView skips the component
    # because no assign of the component changed.
    test "proves the design page: an assign inside a lazy test is tracked like a plain value" do
      for template <- [&lazy_template/1, &plain_template/1] do
        changed = template.(%{user: 1, other: 2, __changed__: %{user: true}}).dynamic.(true)
        unchanged = template.(%{user: 1, other: 2, __changed__: %{other: true}}).dynamic.(true)

        assert [%Rendered{}] = changed
        assert unchanged == [nil]
      end
    end

    test "treats a function of another arity as a truthy value, and does not call it" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.choose>
          <:when :let={value} test={fn _ -> crash!() end}>{is_function(value, 1)}</:when>
        </.choose>
        """)

      assert html == "true"
    end
  end

  describe "switch/1" do
    test "renders the first case with an equal value, in source order" do
      assigns = %{status: :done}

      html =
        rendered_to_string(~H"""
        <.switch value={@status}>
          <:case value={:loading}>a</:case>
          <:case value={:done}>b</:case>
          <:case value={:done}>c</:case>
          <:otherwise>d</:otherwise>
        </.switch>
        """)

      assert html == "b"
    end

    test "gives a case slot the argument nil" do
      assigns = %{}

      assert rendered_to_string(~H"<.switch value={1}><:case :let={arg} value={1}>{inspect(arg)}</:case></.switch>") ==
               "nil"
    end

    test "compares with strict equality, so 1 and 1.0 differ" do
      for {value, expected} <- [{1, "integer"}, {1.0, "float"}] do
        assigns = %{value: value}

        html =
          rendered_to_string(~H"""
          <.switch value={@value}>
            <:case value={1}>integer</:case>
            <:case value={1.0}>float</:case>
          </.switch>
          """)

        assert html == expected
      end
    end

    test "renders the otherwise slot, or nothing, when no case matches" do
      assigns = %{status: :unknown}

      assert rendered_to_string(
               ~H"<.switch value={@status}><:case value={:done}>a</:case><:otherwise>b</:otherwise></.switch>"
             ) == "b"

      assert rendered_to_string(~H"<.switch value={@status}><:case value={:done}>a</:case></.switch>") == ""
    end

    test "renders nothing for a self-closing case that matches, and stops the search" do
      assigns = %{status: :done}

      html =
        rendered_to_string(~H"""
        <.switch value={@status}>
          <:case value={:done} />
          <:case value={:done}>a</:case>
          <:otherwise>b</:otherwise>
        </.switch>
        """)

      assert html == ""
    end

    test "raises ArgumentError for two otherwise slots" do
      assigns = %{}

      assert_raise ArgumentError, "<.switch> accepts one <:otherwise> slot at most. It received 2.", fn ->
        rendered_to_string(~H"""
        <.switch value={:x}>
          <:case value={:y}>a</:case>
          <:otherwise>b</:otherwise>
          <:otherwise>c</:otherwise>
        </.switch>
        """)
      end
    end

    test "renders each branch of the first example in the docs" do
      for {status, expected} <- [
            {:loading, "<span>Loading</span>"},
            {:failed, ~s(<p class="error">The search failed.</p>)},
            {:done, "<ul>1 rows</ul>"}
          ] do
        assigns = %{status: status, rows: [1]}

        html =
          rendered_to_string(~H"""
          <.switch value={@status}>
            <:case value={:loading}><.spinner /></:case>
            <:case value={:failed}><p class="error">The search failed.</p></:case>
            <:otherwise><.results rows={@rows} /></:otherwise>
          </.switch>
          """)

        assert html == expected
      end
    end

    test "renders the :for example in the docs" do
      assigns = %{step: :pay, steps: [cart: "Cart", pay: "Payment", ship: "Shipping"]}

      html =
        rendered_to_string(~H"""
        <.switch value={@step}>
          <:case :for={{step, label} <- @steps} value={step}>{label}</:case>
        </.switch>
        """)

      assert html == "Payment"
    end

    test "removes a case with a falsy :if" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.switch value={:a}>
          <:case :if={false} value={:a}>first</:case>
          <:case value={:a}>second</:case>
        </.switch>
        """)

      assert html == "second"
    end

    test "runs only the body of the selected case" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.switch value={:b}>
          <:case value={:a}>{crash!()}</:case>
          <:case value={:b}>ok</:case>
          <:otherwise>{crash!()}</:otherwise>
        </.switch>
        """)

      assert html == "ok"
    end
  end

  describe "result/1" do
    test "renders each form of a result with its argument" do
      for {value, expected} <- [
            {{:ok, "Ada"}, "ok &quot;Ada&quot;"},
            {:ok, "ok nil"},
            {{:error, :timeout}, "error :timeout"},
            {:error, "error nil"}
          ] do
        assigns = %{value: value}

        html =
          rendered_to_string(~H"""
          <.result value={@value}>
            <:ok :let={ok_value}>ok {inspect(ok_value)}</:ok>
            <:error :let={reason}>error {inspect(reason)}</:error>
          </.result>
          """)

        assert html == expected
      end
    end

    test "renders nothing when the slot of the result is absent or self-closing" do
      assigns = %{}

      assert rendered_to_string(~H"<.result value={{:ok, 1}}><:error>e</:error></.result>") == ""
      assert rendered_to_string(~H"<.result value={:error}><:ok>o</:ok></.result>") == ""
      assert rendered_to_string(~H"<.result value={:ok}><:ok /><:error>e</:error></.result>") == ""
    end

    test "proves the docs: HEEx renders a reason that is a string, an atom or a number, and raises for others" do
      for {reason, expected} <- [{"taken", "taken"}, {:timeout, "timeout"}, {42, "42"}] do
        assigns = %{save: {:error, reason}}
        assert rendered_to_string(~H"<.result value={@save}><:error :let={why}>{why}</:error></.result>") == expected
      end

      for reason <- [{:invalid, "x"}, %{errors: [name: "taken"]}] do
        assigns = %{save: {:error, opaque(reason)}}

        assert_raise Protocol.UndefinedError, fn ->
          rendered_to_string(~H"<.result value={@save}><:error :let={why}>{why}</:error></.result>")
        end
      end
    end

    test "raises FunctionClauseError for a value that is not a result" do
      for value <- [nil, {:ok, 1, 2}, {:other, 1}, "ok"] do
        assigns = %{value: opaque(value)}

        assert_raise FunctionClauseError, fn ->
          rendered_to_string(~H"<.result value={@value}><:ok>o</:ok></.result>")
        end
      end
    end

    test "raises ArgumentError for two ok slots or two error slots" do
      assigns = %{}

      assert_raise ArgumentError, "<.result> accepts one <:ok> slot at most. It received 2.", fn ->
        rendered_to_string(~H"<.result value={:error}><:ok>a</:ok><:ok>b</:ok><:error>c</:error></.result>")
      end

      assert_raise ArgumentError, "<.result> accepts one <:error> slot at most. It received 2.", fn ->
        rendered_to_string(~H"<.result value={:ok}><:ok>a</:ok><:error>b</:error><:error>c</:error></.result>")
      end
    end

    test "renders each branch of the first example in the docs" do
      for {save, expected} <- [
            {{:ok, %{name: "Ada"}}, "Saved Ada."},
            {{:error, "The name is taken."}, ~s(<p class="error">The name is taken.</p>)}
          ] do
        assigns = %{save: save}

        html =
          rendered_to_string(~H"""
          <.result value={@save}>
            <:ok :let={user}>Saved {user.name}.</:ok>
            <:error :let={reason}><p class="error">{reason}</p></:error>
          </.result>
          """)

        assert html == expected
      end
    end

    test "renders the :if example in the docs" do
      for {save, expected} <- [{nil, ""}, {{:ok, 1}, ""}, {{:error, :taken}, "The save failed."}] do
        assigns = %{save: save}

        html =
          rendered_to_string(~H"""
          <.result :if={@save} value={@save}>
            <:error>The save failed.</:error>
          </.result>
          """)

        assert String.trim(html) == expected
      end
    end

    test "runs only the body of the selected slot" do
      assigns = %{}

      assert rendered_to_string(~H"<.result value={:ok}><:ok>ok</:ok><:error>{crash!()}</:error></.result>") ==
               "ok"
    end
  end

  describe "wrap_if/1" do
    test "renders only the content when the test is falsy" do
      for test <- [nil, false] do
        assigns = %{test: test}

        html =
          rendered_to_string(~H"""
          <.wrap_if test={@test}><:wrapper :let={content}><b>{render_slot(content)}</b></:wrapper>a</.wrap_if>
          """)

        assert String.trim(html) == "a"
      end
    end

    test "puts the content into the wrapper when the test is truthy" do
      for test <- [true, 0, "", []] do
        assigns = %{test: test}

        html =
          rendered_to_string(~H"""
          <.wrap_if test={@test}><:wrapper :let={content}><b>{render_slot(content)}</b></:wrapper>a</.wrap_if>
          """)

        assert String.trim(html) == "<b>a</b>", "expected a wrapper for #{inspect(test)}"
      end
    end

    test "renders each branch of the first example in the docs" do
      for {user, expected} <- [
            {%{name: "Ada", profile_url: "/users/ada"}, ~s(<a href="/users/ada">Ada</a>)},
            {%{name: "Grace", profile_url: nil}, "Grace"}
          ] do
        assigns = %{user: user}

        html =
          rendered_to_string(~H"""
          <.wrap_if test={@user.profile_url}>
            <:wrapper :let={content}><a href={@user.profile_url}>{render_slot(content)}</a></:wrapper>
            {@user.name}
          </.wrap_if>
          """)

        assert html
               |> String.replace(~r/\s+/, " ")
               |> String.trim()
               |> String.replace("> ", ">")
               |> String.replace(" <", "<") ==
                 expected
      end
    end

    test "proves the docs: the body of the wrapper runs only when the test is truthy" do
      for {tooltip, expected} <- [
            {nil, "Save"},
            {%{text: "Saves the form"}, ~s(<span title="Saves the form">Save</span>)}
          ] do
        assigns = %{tooltip: opaque(tooltip), label: "Save"}

        html =
          rendered_to_string(~H"""
          <.wrap_if test={@tooltip}>
            <:wrapper :let={content}><span title={@tooltip.text}>{render_slot(content)}</span></:wrapper>
            {@label}
          </.wrap_if>
          """)

        assert html |> String.replace(~r/\s*\n\s*/, "") |> String.trim() == expected
      end
    end

    test "calls a lazy test one time for each render" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.wrap_if test={fn -> mark(:called) end}><:wrapper :let={content}><b>{render_slot(content)}</b></:wrapper>a</.wrap_if>
        """)

      assert String.trim(html) == "<b>a</b>"
      assert_received {:ran, :called}
      refute_received {:ran, :called}
    end

    test "proves the warning in the docs: a wrapper that does not render its argument hides the content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.wrap_if test={true}><:wrapper><b>no content</b></:wrapper><i id="item">a</i></.wrap_if>
        """)

      assert String.trim(html) == "<b>no content</b>"
    end

    test "proves the warning in the docs: a wrapper that renders its argument two times repeats each id" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.wrap_if test={true}><:wrapper :let={content}>{render_slot(content)}{render_slot(content)}</:wrapper><i id="item">a</i></.wrap_if>
        """)

      assert String.trim(html) == ~s(<i id="item">a</i><i id="item">a</i>)
    end

    test "raises ArgumentError for a self-closing wrapper" do
      assigns = %{}

      assert_raise ArgumentError,
                   "<.wrap_if> needs a <:wrapper> slot with a body. A self-closing <:wrapper /> hides the content.",
                   fn -> rendered_to_string(~H"<.wrap_if test={true}><:wrapper />a</.wrap_if>") end
    end

    test "raises ArgumentError for two wrappers" do
      assigns = %{}

      assert_raise ArgumentError, "<.wrap_if> accepts one <:wrapper> slot at most. It received 2.", fn ->
        rendered_to_string(~H"""
        <.wrap_if test={true}><:wrapper :let={c}>{render_slot(c)}</:wrapper><:wrapper :let={c}>{render_slot(c)}</:wrapper>a</.wrap_if>
        """)
      end
    end

    test "renders the content with no wrapper when :if removes the wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.wrap_if test={true}><:wrapper :if={false} :let={content}><b>{render_slot(content)}</b></:wrapper>a</.wrap_if>
        """)

      assert String.trim(html) == "a"
    end

    test "proves the docs: LiveView sends the static HTML of the content again only when the test changes" do
      {_first, same_test} =
        second_diff(&profile_link/1, %{url: nil, name: "Ada"}, %{url: nil, name: "Grace"}, %{name: true})

      {_first, changed_test} =
        second_diff(&profile_link/1, %{url: nil, name: "Ada"}, %{url: "/users/ada", name: "Ada"}, %{url: true})

      assert same_test =~ "Grace"
      refute same_test =~ "static text"
      assert changed_test =~ "static text"
    end
  end

  describe "each/1" do
    test "renders the content for each item, in order, and binds the item with :let" do
      assigns = %{users: [%{name: "Ada"}, %{name: "Grace"}]}

      html =
        rendered_to_string(~H"""
        <ul><.each :let={user} items={@users}><li>{user.name}</li><:empty><li>No users.</li></:empty></.each></ul>
        """)

      assert String.trim(html) == "<ul><li>Ada</li><li>Grace</li></ul>"
    end

    test "renders the empty slot, or nothing, for an enumerable with no items" do
      for items <- [[], %{}, 1..0//1, MapSet.new()] do
        assigns = %{items: items}

        assert rendered_to_string(~H"<.each :let={i} items={@items}>{i}<:empty>none</:empty></.each>") == "none"
        assert rendered_to_string(~H"<.each :let={i} items={@items}>{i}</.each>") == ""
        assert rendered_to_string(~H"<.each :let={i} items={@items}>{i}<:empty /></.each>") == ""
      end
    end

    test "renders the example in the docs for each case" do
      for {users, expected} <- [
            {[%{name: "Ada"}], "<ul><li>Ada</li></ul>"},
            {[], "<ul><li>No users.</li></ul>"}
          ] do
        assigns = %{users: users}

        html =
          rendered_to_string(~H"""
          <ul>
            <.each :let={user} items={@users}>
              <li>{user.name}</li>
              <:empty><li>No users.</li></:empty>
            </.each>
          </ul>
          """)

        assert String.replace(html, ~r/\s*\n\s*/, "") == expected
      end
    end

    test "accepts a range and a map, and gives a map entry as a tuple" do
      assigns = %{}

      assert rendered_to_string(~H"<.each :let={n} items={1..3}>{n}</.each>") == "123"
      assert rendered_to_string(~H"<.each :let={{k, v}} items={%{a: 1}}>{k}={v}</.each>") == "a=1"
    end

    test "converts a lazy enumerable into a list one time for each render" do
      assigns = %{items: Stream.map([1, 2], &mark/1)}

      assert rendered_to_string(~H"<.each :let={n} items={@items}>{n}<:empty>none</:empty></.each>") == "12"
      assert_received {:ran, 1}
      assert_received {:ran, 2}
      refute_received {:ran, _}
    end

    test "raises Protocol.UndefinedError for nil, as the docs tell" do
      assigns = %{items: opaque(nil)}

      assert_raise Protocol.UndefinedError, fn ->
        rendered_to_string(~H"<.each :let={n} items={@items}>{n}</.each>")
      end

      assigns = %{items: opaque(nil)}
      assert rendered_to_string(~H"<.each :let={n} items={@items || []}>{n}<:empty>none</:empty></.each>") == "none"
    end

    test "raises ArgumentError for a stream" do
      # stream/3 needs the lifecycle of a mounted socket. LiveView builds the same
      # socket for a function component in Phoenix.LiveView.Diff.
      socket = %Socket{private: %{lifecycle: %Lifecycle{}}}
      socket = Phoenix.LiveView.stream(socket, :users, [%{id: 1, name: "Ada"}])
      assigns = %{streams: socket.assigns.streams}

      assert_raise ArgumentError, ~r/<.each> does not accept a stream/, fn ->
        rendered_to_string(~H"<.each :let={user} items={@streams.users}>{inspect(user)}</.each>")
      end
    end

    test "gives the empty slot the argument nil" do
      assigns = %{}

      assert rendered_to_string(~H"<.each :let={n} items={[]}>{n}<:empty :let={arg}>{inspect(arg)}</:empty></.each>") ==
               "nil"
    end

    test "raises ArgumentError for two empty slots" do
      assigns = %{}

      assert_raise ArgumentError, "<.each> accepts one <:empty> slot at most. It received 2.", fn ->
        rendered_to_string(~H"<.each :let={n} items={[]}>{n}<:empty>a</:empty><:empty>b</:empty></.each>")
      end
    end

    test "runs the empty slot only for an empty list" do
      assigns = %{}
      assert rendered_to_string(~H"<.each :let={n} items={[1]}>{n}<:empty>{crash!()}</:empty></.each>") == "1"
    end

    test "renders the :for alternative in the docs for each case" do
      for {users, expected} <- [
            {[%{id: 1, name: "Ada"}], "<ul><li>Ada</li></ul>"},
            {[], "<ul><li>No users.</li></ul>"}
          ] do
        assigns = %{users: users}

        html =
          rendered_to_string(~H"""
          <ul>
            <li :for={user <- @users} :key={user.id}>{user.name}</li>
            <li :if={@users == []}>No users.</li>
          </ul>
          """)

        assert String.replace(html, ~r/\s*\n\s*/, "") == expected
      end
    end
  end

  describe "each/1: change tracking, as the docs tell" do
    @items for n <- 1..20, do: "item-#{n}"

    test "sends only the new item when an item is added at the end" do
      {_first, diff} = second_diff(&list_with_each/1, %{items: @items}, %{items: @items ++ ["item-21"]}, %{items: true})

      assert diff =~ "item-21"
      refute diff =~ "item-20"
    end

    test "sends only the changed item when one item changes" do
      changed = List.replace_at(@items, 9, "changed")
      {_first, diff} = second_diff(&list_with_each/1, %{items: @items}, %{items: changed}, %{items: true})

      assert diff =~ "changed"
      refute diff =~ "item-11"
    end

    test "sends each later item again when an item is added at the start, and :for with :key does not" do
      {_first, each_diff} =
        second_diff(&list_with_each/1, %{items: @items}, %{items: ["item-0" | @items]}, %{items: true})

      {_first, key_diff} =
        second_diff(&list_with_key/1, %{items: @items}, %{items: ["item-0" | @items]}, %{items: true})

      assert each_diff =~ "item-15"
      refute key_diff =~ "item-15"
      assert byte_size(key_diff) < byte_size(each_diff)
    end

    test "has a larger first render than the same :for" do
      {each_first, _diff} = second_diff(&list_with_each/1, %{items: @items}, %{items: @items}, %{})
      {key_first, _diff} = second_diff(&list_with_key/1, %{items: @items}, %{items: @items}, %{})

      assert byte_size(each_first) > byte_size(key_first)
    end
  end

  describe "whitespace of each component" do
    test "adds no whitespace around the selected body" do
      assigns = %{}

      assert rendered_to_string(~H"<span><.choose><:when test={true}>a</:when></.choose>!</span>") ==
               "<span>a!</span>"

      assert rendered_to_string(
               ~H"<span><.choose><:when test={false}>a</:when><:otherwise>b</:otherwise></.choose>!</span>"
             ) == "<span>b!</span>"

      assert rendered_to_string(~H"<span><.choose><:when test={false}>a</:when></.choose>!</span>") ==
               "<span>!</span>"

      assert rendered_to_string(~H"<span><.switch value={1}><:case value={1}>a</:case></.switch>!</span>") ==
               "<span>a!</span>"

      assert rendered_to_string(~H"<span><.result value={:ok}><:ok>a</:ok></.result>!</span>") ==
               "<span>a!</span>"
    end
  end

  describe "compile-time warnings" do
    # LiveView also prints these warnings. with_io/2 hides that output, and
    # Warnings.collect/1 returns the warnings of this process only.
    defp compile_warnings(name, template) do
      code = """
      defmodule ShoddyPhoenix.ControlFlowTest.#{name} do
        use Phoenix.Component
        import ShoddyPhoenix.ControlFlow

        def render(assigns) do
          ~H\"\"\"
          #{template}
          \"\"\"
        end
      end
      """

      {warnings, _output} = with_io(:stderr, fn -> Warnings.collect(fn -> Code.compile_string(code) end) end)
      warnings
    end

    test "warns about a slot with no test" do
      warnings = compile_warnings("NoTest", "<.choose><:when>a</:when></.choose>")

      assert warnings =~
               ~s(missing required attribute "test" in slot "when" for component ShoddyPhoenix.ControlFlow.choose/1)
    end

    test "warns about a misspelt attribute" do
      warnings = compile_warnings("Misspelt", "<.choose><:when tset={true}>a</:when></.choose>")

      assert warnings =~
               ~s(undefined attribute "tset" in slot "when" for component ShoddyPhoenix.ControlFlow.choose/1)
    end

    test "warns about a component with no when slot" do
      warnings = compile_warnings("NoWhen", "<.choose><:otherwise>a</:otherwise></.choose>")

      assert warnings =~
               ~s(missing required slot "when" for component ShoddyPhoenix.ControlFlow.choose/1)
    end

    test "warns about a case with no value" do
      warnings = compile_warnings("NoValue", "<.switch value={1}><:case>a</:case></.switch>")

      assert warnings =~
               ~s(missing required attribute "value" in slot "case" for component ShoddyPhoenix.ControlFlow.switch/1)
    end

    test "proves the design page: a component with the name cond cannot compile" do
      code = """
      defmodule ShoddyPhoenix.ControlFlowTest.NamedCond do
        use Phoenix.Component

        def cond(assigns), do: ~H"{render_slot(@inner_block)}"

        def render(assigns), do: ~H"<.cond>a</.cond>"
      end
      """

      errors = Warnings.collect(fn -> assert_raise CompileError, fn -> Code.compile_string(code) end end)

      assert errors =~ ~s(invalid arguments for "cond")
    end
  end
end
