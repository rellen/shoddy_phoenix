defmodule ShoddyPhoenix.ControlFlowTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import ShoddyPhoenix.ControlFlow

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

  defp crash!, do: raise("this body must not run")

  # These components stand in for the components of the examples in the docs.
  defp spinner(assigns), do: ~H"<span>Loading</span>"
  defp results(assigns), do: ~H"<ul>{length(@rows)} rows</ul>"

  describe "selection" do
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

  describe "fallbacks" do
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
  end

  describe "slot features" do
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

  describe "lazy bodies" do
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

  describe "eager tests, as the section Evaluation order of the docs tells" do
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

  describe "the guards in the docs" do
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
  end

  describe "whitespace" do
    test "adds no whitespace around the selected body" do
      assigns = %{}

      assert rendered_to_string(~H"<span><.choose><:when test={true}>a</:when></.choose>!</span>") ==
               "<span>a!</span>"

      assert rendered_to_string(
               ~H"<span><.choose><:when test={false}>a</:when><:otherwise>b</:otherwise></.choose>!</span>"
             ) == "<span>b!</span>"

      assert rendered_to_string(~H"<span><.choose><:when test={false}>a</:when></.choose>!</span>") ==
               "<span>!</span>"
    end
  end

  describe "compile-time warnings" do
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

      capture_io(:stderr, fn -> Code.compile_string(code) end)
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

    test "proves the design page: a component with the name cond cannot compile" do
      code = """
      defmodule ShoddyPhoenix.ControlFlowTest.NamedCond do
        use Phoenix.Component

        def cond(assigns), do: ~H"{render_slot(@inner_block)}"

        def render(assigns), do: ~H"<.cond>a</.cond>"
      end
      """

      errors =
        capture_io(:stderr, fn ->
          assert_raise CompileError, fn -> Code.compile_string(code) end
        end)

      assert errors =~ ~s(invalid arguments for "cond")
    end
  end
end
