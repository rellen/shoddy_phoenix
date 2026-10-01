defmodule ShoddyPhoenix.LiveView.EventsTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias ShoddyPhoenix.Test.ChatWidget
  alias ShoddyPhoenix.Test.Endpoint
  alias ShoddyPhoenix.Test.Warnings

  @endpoint Endpoint

  # Compiles the code in the file name.ex, and returns the warnings. Each
  # test gives its own name, so the tests do not define a module two times.
  defp compile_warnings(name, code) do
    Warnings.collect(fn -> Code.compile_string(code, "#{name}.ex") end)
  end

  # Returns the code of a LiveView with this template and these clauses of
  # handle_event/3. The template starts on line 7.
  defp live_view(name, template, clauses) do
    """
    defmodule ShoddyPhoenix.LiveView.EventsTest.#{name} do
      use Phoenix.LiveView
      use ShoddyPhoenix.LiveView.Events

      def render(assigns) do
        ~H\"\"\"
        #{template}
        \"\"\"
      end

      #{clauses}
    end
    """
  end

  defp handled(name, template, clauses) do
    compile_warnings(name, live_view(name, template, clauses))
  end

  # Calls a function of a module that a test compiles. The compiler of this
  # file does not know that module, so the test does not name it directly.
  defp call(name, function), do: apply(Module.concat(__MODULE__, name), function, [])

  defp missing(name, event) do
    "ShoddyPhoenix.LiveView.EventsTest.#{name} has no clause of handle_event/3 for the event #{inspect(event)}"
  end

  describe "event/1 at the run time" do
    test "returns the name, and the event goes to handle_event/3" do
      {:ok, view, html} = live(build_conn(), "/counter")

      assert html =~ ~s(phx-click="inc")
      assert html =~ ~s(phx-click="dec")

      view |> element("button", "+") |> render_click()
      view |> element("button", "+") |> render_click()
      view |> element("button", "-") |> render_click()

      assert view |> element("#count") |> render() =~ "count 1"
    end

    test "works in a LiveComponent" do
      {:ok, view, _html} = live(build_conn(), "/counter")

      view |> element("button", "Like") |> render_click()

      assert view |> element("#likes") |> render() =~ "likes 1"
    end

    test "puts the prefix and a colon in front of the name" do
      html =
        rendered_to_string(ChatWidget.render(%{state: %ChatWidget{key: :left_chat, topic: "t"}}))

      assert html =~ ~s(phx-submit="chat:send")
    end
  end

  describe "the check" do
    test "does not warn when each name has a clause" do
      warnings =
        handled("Each", ~s|<button phx-click={event("inc")}>+</button>|, """
        def handle_event("inc", _params, socket), do: {:noreply, socket}
        """)

      assert warnings == ""
    end

    test "warns at the line of a name that has no clause" do
      template = """
      <button phx-click={event("inc")}>+</button>
          <button phx-click={event("decc")}>-</button>
      """

      warnings =
        handled("Missing", template, """
        def handle_event("inc", _params, socket), do: {:noreply, socket}
        def handle_event("dec", _params, socket), do: {:noreply, socket}
        """)

      assert warnings =~ missing("Missing", "decc")
      assert warnings =~ "Missing.ex:8"
      refute warnings =~ ~s(event "inc")
    end

    test "warns at each use of a name that has no clause" do
      template = """
      <button phx-click={event("save")}>Save</button>
          <button phx-click={event("save")}>Save</button>
      """

      warnings = handled("EachUse", template, "")

      assert warnings =~ "EachUse.ex:7"
      assert warnings =~ "EachUse.ex:8"
    end

    test "warns about a module with no handle_event/3" do
      warnings = handled("NoClause", ~s|<button phx-click={event("save")}>Save</button>|, "")

      assert warnings =~ missing("NoClause", "save")
    end

    test "gives no warning for a module that does not call event/1" do
      warnings =
        handled("NoEvent", "<p>plain</p>", """
        def handle_event("inc", _params, socket), do: {:noreply, socket}
        """)

      assert warnings == ""
    end

    test "does not see a name that a template writes as a plain string" do
      warnings =
        handled("PlainString", ~s|<button phx-click="decc">-</button>|, """
        def handle_event("dec", _params, socket), do: {:noreply, socket}
        """)

      assert warnings == ""
    end

    test "gives a diagnostic with the severity that --warnings-as-errors counts" do
      code = live_view("Severity", ~s|<button phx-click={event("decc")}>-</button>|, "")

      {_result, diagnostics} =
        Code.with_diagnostics([log: false], fn -> Code.compile_string(code, "Severity.ex") end)

      assert [%{severity: :warning, position: 7, file: "Severity.ex"}] = diagnostics
    end

    test "does not warn about a clause that no template uses" do
      warnings =
        handled("Unused", ~s|<button phx-click={event("inc")}>+</button>|, """
        def handle_event("inc", _params, socket), do: {:noreply, socket}
        def handle_event("reset", _params, socket), do: {:noreply, socket}
        """)

      assert warnings == ""
    end

    test "finds a clause with a guard" do
      warnings =
        handled("Guard", ~s|<button phx-click={event("inc")}>+</button>|, """
        def handle_event("inc", params, socket) when is_map(params), do: {:noreply, socket}
        """)

      assert warnings == ""
    end

    test "accepts each name that starts with the prefix of a clause" do
      template = """
      <button phx-click={event("item:7")}>7</button>
          <button phx-click={event("row:2")}>2</button>
          <button phx-click={event("other")}>?</button>
      """

      warnings =
        handled("Prefix", template, """
        def handle_event("item:" <> _id, _params, socket), do: {:noreply, socket}
        def handle_event(<<"row:", _id::binary>>, _params, socket), do: {:noreply, socket}
        """)

      assert warnings =~ missing("Prefix", "other")
      refute warnings =~ ~s(event "item:7")
      refute warnings =~ ~s(event "row:2")
    end

    test "reads a clause of literal parts as one name" do
      template = """
      <button phx-click={event("item:7")}>7</button>
          <button phx-click={event("item:78")}>78</button>
      """

      warnings =
        handled("Parts", template, """
        def handle_event("item:" <> "7", _params, socket), do: {:noreply, socket}
        """)

      assert warnings =~ missing("Parts", "item:78")
      refute warnings =~ ~s(event "item:7")
    end

    test "reads a name on each side of a match" do
      template = """
      <button phx-click={event("save")}>Save</button>
          <button phx-click={event("load")}>Load</button>
          <button phx-click={event("drop")}>Drop</button>
      """

      warnings =
        handled("Match", template, """
        def handle_event("save" = event, _params, socket), do: {:noreply, assign(socket, :event, event)}
        def handle_event(event = "load", _params, socket), do: {:noreply, assign(socket, :event, event)}
        """)

      assert warnings =~ missing("Match", "drop")
      refute warnings =~ ~s(event "save")
      refute warnings =~ ~s(event "load")
    end

    test "does not warn when a clause can handle each name" do
      warnings =
        handled("CatchAll", ~s|<button phx-click={event("decc")}>-</button>|, """
        def handle_event("inc", _params, socket), do: {:noreply, socket}
        def handle_event(_event, _params, socket), do: {:noreply, socket}
        """)

      assert warnings == ""
    end

    test "does not warn when a segment of a binary pattern is not a plain string" do
      warnings =
        compile_warnings("Utf16", """
        defmodule ShoddyPhoenix.LiveView.EventsTest.Utf16 do
          use ShoddyPhoenix.LiveView.Events

          def name, do: event("\\0a")
          def handle_event(<<"a"::utf16, _rest::binary>>, _params, socket), do: socket
        end
        """)

      assert warnings == ""
    end

    test "does not warn when a match has no literal" do
      warnings =
        handled("MatchAll", ~s|<button phx-click={event("decc")}>-</button>|, """
        def handle_event(event = name, _params, socket), do: {:noreply, assign(socket, :event, {event, name})}
        """)

      assert warnings == ""
    end

    test "reads a template in a separate file" do
      dir = Path.join(System.tmp_dir!(), "shoddy_phoenix_events_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "colocated_live.html.heex"), """
      <button phx-click={event("inc")}>+</button>
      <button phx-click={event("decc")}>-</button>
      """)

      file = Path.join(dir, "colocated_live.ex")

      File.write!(file, """
      defmodule ShoddyPhoenix.LiveView.EventsTest.ColocatedLive do
        use ShoddyPhoenix.LiveView.Events
        use Phoenix.LiveView

        def handle_event("inc", _params, socket), do: {:noreply, socket}
      end
      """)

      warnings = Warnings.collect(fn -> Code.compile_file(file) end)

      assert warnings =~ missing("ColocatedLive", "decc")
      assert warnings =~ "colocated_live.html.heex:2"
      refute warnings =~ ~s(event "inc")
    end

    test "works in a LiveComponent" do
      warnings =
        compile_warnings("Component", """
        defmodule ShoddyPhoenix.LiveView.EventsTest.Component do
          use Phoenix.LiveComponent
          use ShoddyPhoenix.LiveView.Events

          def render(assigns) do
            ~H\"\"\"
            <div>
              <button phx-click={event("like")} phx-target={@myself}>Like</button>
              <button phx-click={event("likee")} phx-target={@myself}>Like</button>
            </div>
            \"\"\"
          end

          def handle_event("like", _params, socket), do: {:noreply, socket}
        end
        """)

      assert warnings =~ missing("Component", "likee")
      refute warnings =~ ~s(event "like")
    end
  end

  describe "the option :prefix" do
    defp widget(name, prefix, clauses) do
      """
      defmodule ShoddyPhoenix.LiveView.EventsTest.#{name} do
        use Phoenix.Component
        use ShoddyPhoenix.LiveView.Events, prefix: #{prefix}

        def render(assigns) do
          ~H\"\"\"
          <form phx-submit={event("send")}></form>
          \"\"\"
        end

        def name, do: event("send")
        def prefix, do: event_prefix()

        #{clauses}
      end
      """
    end

    test "puts the prefix and a colon in front of the name" do
      warnings =
        compile_warnings(
          "Widget",
          widget("Widget", ~s("chat"), "def handle_event(\"send\", _params, socket), do: socket")
        )

      assert warnings == ""
      assert call("Widget", :name) == "chat:send"
    end

    test "returns the prefix with event_prefix/0" do
      compile_warnings(
        "WidgetPrefix",
        widget("WidgetPrefix", ~s("chat"), "def handle_event(\"send\", _params, socket), do: socket")
      )

      assert call("WidgetPrefix", :prefix) == "chat"
    end

    test "finds a private clause" do
      clauses = """
      def assign_widget(socket), do: ShoddyPhoenix.LiveView.Widgets.route_events(socket, event_prefix(), &handle_event/3)
      defp handle_event("send", _params, socket), do: {:noreply, socket}
      """

      assert compile_warnings("WidgetPrivate", widget("WidgetPrivate", ~s("chat"), clauses)) == ""
    end

    test "looks for a clause for the name without the prefix" do
      warnings =
        compile_warnings(
          "WidgetMissing",
          widget("WidgetMissing", ~s("chat"), "def handle_event(\"chat:send\", _params, socket), do: socket")
        )

      assert warnings =~ missing("WidgetMissing", "send")
    end

    test "raises for a prefix that is empty, contains a colon or is not a literal string" do
      for {prefix, message} <- [
            {~s(""), ~s(It was "".)},
            {~s("chat:room"), ~s(It was "chat:room".)},
            {":chat", "must be a literal string. It was :chat."},
            {"@widget", "must be a literal string. It was @widget."}
          ] do
        error =
          assert_raise ArgumentError, fn ->
            Code.compile_string("""
            defmodule ShoddyPhoenix.LiveView.EventsTest.BadPrefix do
              @widget "chat"
              use ShoddyPhoenix.LiveView.Events, prefix: #{prefix}
            end
            """)
          end

        assert Exception.message(error) =~ message
      end
    end

    test "runs the check one time for a second use with the same prefix" do
      warnings =
        compile_warnings("TwoUses", """
        defmodule ShoddyPhoenix.LiveView.EventsTest.TwoUses do
          use ShoddyPhoenix.LiveView.Events, prefix: "chat"
          use ShoddyPhoenix.LiveView.Events, prefix: "chat"

          def name, do: event("send")
        end
        """)

      assert [_before, _after] = String.split(warnings, missing("TwoUses", "send"))
    end

    test "raises for a second use with another prefix" do
      assert_raise ArgumentError,
                   ~r/uses ShoddyPhoenix.LiveView.Events two times, with the prefixes "chat" and nil/,
                   fn ->
                     Code.compile_string("""
                     defmodule ShoddyPhoenix.LiveView.EventsTest.TwoPrefixes do
                       use ShoddyPhoenix.LiveView.Events, prefix: "chat"
                       use ShoddyPhoenix.LiveView.Events
                     end
                     """)
                   end
    end

    test "raises for an unknown option" do
      assert_raise ArgumentError, ~r/unknown keys \[:prefx\]/, fn ->
        Code.compile_string("""
        defmodule ShoddyPhoenix.LiveView.EventsTest.BadOption do
          use ShoddyPhoenix.LiveView.Events, prefx: "chat"
        end
        """)
      end
    end

    test "makes event_prefix/0 raise at the compile time for a module without a prefix" do
      assert_raise ArgumentError, ~r/event_prefix\/0 needs the option :prefix/, fn ->
        Code.compile_string("""
        defmodule ShoddyPhoenix.LiveView.EventsTest.NoPrefix do
          use ShoddyPhoenix.LiveView.Events

          def prefix, do: event_prefix()
        end
        """)
      end
    end
  end

  describe "the compile-time errors of the macros" do
    test "raises at the compile time for a name that is not a literal string" do
      assert_raise ArgumentError, ~r/event\/1 needs a literal string.*It received name\./, fn ->
        Code.compile_string("""
        defmodule ShoddyPhoenix.LiveView.EventsTest.NotLiteral do
          use ShoddyPhoenix.LiveView.Events

          def click(name), do: event(name)
        end
        """)
      end
    end

    test "raises at the compile time for a module without the use" do
      assert_raise ArgumentError, ~r/event\/1 needs `use ShoddyPhoenix.LiveView.Events`/, fn ->
        Code.compile_string("""
        defmodule ShoddyPhoenix.LiveView.EventsTest.NoUse do
          import ShoddyPhoenix.LiveView.Events

          def click, do: event("save")
        end
        """)
      end
    end

    test "raises at the compile time outside a module" do
      assert_raise ArgumentError, ~r/event\/1 needs `use ShoddyPhoenix.LiveView.Events`/, fn ->
        Code.eval_string(~s|import ShoddyPhoenix.LiveView.Events; event("save")|)
      end
    end

    test "raises at the compile time for event_prefix/0 in a module without the use" do
      assert_raise ArgumentError, ~r/event_prefix\/0 needs `use ShoddyPhoenix.LiveView.Events`/, fn ->
        Code.compile_string("""
        defmodule ShoddyPhoenix.LiveView.EventsTest.PrefixNoUse do
          import ShoddyPhoenix.LiveView.Events

          def prefix, do: event_prefix()
        end
        """)
      end
    end
  end
end
