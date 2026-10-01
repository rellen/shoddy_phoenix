defmodule ShoddyPhoenix.LiveView.WidgetsTest.OtherWidget do
  # The handler of this module asks for a name that another module uses.
  @moduledoc false
  def handle_event(_action, _params, socket), do: {:noreply, socket}
end

defmodule ShoddyPhoenix.LiveView.WidgetsTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveView.Lifecycle
  alias Phoenix.LiveView.Socket
  alias ShoddyPhoenix.LiveView.Widgets
  alias ShoddyPhoenix.LiveView.WidgetsTest.OtherWidget
  alias ShoddyPhoenix.Test.ChatWidget
  alias ShoddyPhoenix.Test.Endpoint
  alias ShoddyPhoenix.Test.GuideChatLive
  alias ShoddyPhoenix.Test.PubSub
  alias ShoddyPhoenix.Test.ReplyLive

  @endpoint Endpoint

  # The type checker of Elixir can warn about a literal that a test gives to
  # a function on purpose, such as a value that is not a socket. This helper
  # returns its argument, and the type checker cannot see through it.
  defp opaque(value), do: Process.get({__MODULE__, :unset}, value)

  # LiveView keeps the hooks in the private data of the socket.
  defp hook_socket, do: %Socket{private: %{lifecycle: %Lifecycle{}}}

  defp handle_event(_action, _params, socket), do: {:noreply, socket}

  # Another function, such as String.contains?/2, can raise the same error
  # for a wrong argument. This helper also checks that the function of this
  # module raises it.
  defp assert_clause_error(function, call) do
    error = assert_raise FunctionClauseError, call
    assert {error.module, error.function} == {Widgets, function}
  end

  describe "route_events/3" do
    test "accepts a second call from the module that uses the name" do
      socket = Widgets.route_events(hook_socket(), "chat", &handle_event/3)

      assert %Socket{} = Widgets.route_events(socket, "chat", &handle_event/3)
    end

    test "raises ArgumentError for a name that a handler of another module uses" do
      socket = Widgets.route_events(hook_socket(), "chat", &handle_event/3)

      assert_raise ArgumentError, ~r/the widget name "chat" belongs to ShoddyPhoenix.LiveView.WidgetsTest/, fn ->
        Widgets.route_events(socket, "chat", &OtherWidget.handle_event/3)
      end
    end

    test "raises ArgumentError for an empty name or a name with a colon" do
      for name <- ["", "chat:send", ":"] do
        assert_raise ArgumentError, ~r/must be a string that is not empty and that contains no colon/, fn ->
          Widgets.route_events(hook_socket(), name, &handle_event/3)
        end
      end
    end

    test "raises FunctionClauseError for a wrong socket, name or handler" do
      assert_clause_error(:route_events, fn -> Widgets.route_events(opaque(%{}), "chat", &handle_event/3) end)
      assert_clause_error(:route_events, fn -> Widgets.route_events(hook_socket(), opaque(:chat), &handle_event/3) end)

      assert_clause_error(:route_events, fn ->
        Widgets.route_events(hook_socket(), "chat", opaque(fn _action, _params -> :ok end))
      end)
    end
  end

  describe "unroute_events/2" do
    test "makes the name free for another module" do
      socket =
        hook_socket()
        |> Widgets.route_events("chat", &handle_event/3)
        |> Widgets.unroute_events("chat")

      assert %Socket{} = Widgets.route_events(socket, "chat", &OtherWidget.handle_event/3)
    end

    test "does nothing for a name that is not in use" do
      socket = Widgets.route_events(hook_socket(), "chat", &handle_event/3)

      assert Widgets.unroute_events(socket, "other") == socket
    end

    test "raises FunctionClauseError for a wrong socket or name" do
      assert_clause_error(:unroute_events, fn -> Widgets.unroute_events(opaque(%{}), "chat") end)
      assert_clause_error(:unroute_events, fn -> Widgets.unroute_events(hook_socket(), opaque(:chat)) end)
    end
  end

  describe "fetch_instance/3" do
    defp instances_socket do
      Phoenix.Component.assign(%Socket{},
        left_chat: %ChatWidget{key: :left_chat, topic: "a"},
        count: 3,
        other: %URI{}
      )
    end

    test "returns the key and the struct of the instance that the name names" do
      assert Widgets.fetch_instance(instances_socket(), ChatWidget, "left_chat") ==
               {:ok, {:left_chat, %ChatWidget{key: :left_chat, topic: "a"}}}
    end

    test "returns :error for an unknown string, an assign of another kind, or a value that is not a string" do
      for name <- ["right_chat", "count", "other", "flash", nil, :left_chat, 1] do
        assert Widgets.fetch_instance(instances_socket(), ChatWidget, name) == :error
      end
    end

    test "makes no atom" do
      name = "shoddy_phoenix_unknown_#{System.unique_integer([:positive])}"

      assert Widgets.fetch_instance(instances_socket(), ChatWidget, name) == :error
      assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    end

    test "raises FunctionClauseError for a wrong socket or module" do
      assert_clause_error(:fetch_instance, fn -> Widgets.fetch_instance(opaque(%{}), ChatWidget, "left_chat") end)

      assert_clause_error(:fetch_instance, fn ->
        Widgets.fetch_instance(instances_socket(), opaque("ChatWidget"), "x")
      end)
    end
  end

  # These tests render a LiveView with two instances of the chat widget of
  # the how-to guide on one topic.
  describe "the chat widget" do
    setup do
      topic = "widgets-test:#{System.unique_integer([:positive])}"
      %{conn: init_test_session(build_conn(), %{"topic" => topic}), topic: topic}
    end

    defp count_messages(view, text) do
      view |> render() |> String.split("<li>#{text}</li>") |> length() |> Kernel.-(1)
    end

    test "shows one broadcast one time in each instance", %{conn: conn, topic: topic} do
      {:ok, view, _html} = live(conn, "/chat")

      Phoenix.PubSub.broadcast(PubSub, topic, {ChatWidget, topic, "Hello"})

      assert count_messages(view, "Hello") == 2
    end

    test "sends a message from the form of one instance to each instance", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat")

      view |> form("#chat-left_chat form", %{"message" => "Hi"}) |> render_submit()

      assert count_messages(view, "Hi") == 2
    end

    test "ignores an empty message and each wrong instance with no crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat")

      view |> form("#chat-left_chat form", %{"message" => "  "}) |> render_submit()

      for params <- [
            %{"instance" => "pings", "message" => "x"},
            %{"instance" => "zz_not_an_atom", "message" => "x"},
            %{"message" => "x"},
            %{"instance" => "left_chat", "message" => %{"nested" => "x"}}
          ] do
        render_submit(view, "chat:send", params)
      end

      refute render(view) =~ "<li>"
    end

    test "sends an event with another name to the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chat")

      render_click(view, "chatter:ping")

      assert view |> element("#pings") |> render() =~ "pings 1"
    end

    test "halts its own messages, and the LiveView gets each other message", %{conn: conn, topic: topic} do
      {:ok, view, _html} = live(conn, "/chat")

      Phoenix.PubSub.broadcast(PubSub, topic, {ChatWidget, topic, "Hello"})
      send(view.pid, :ping)

      assert view |> element("#pings") |> render() =~ "pings 1"
    end

    test "keeps the subscription of one instance when the other instance goes", %{conn: conn, topic: topic} do
      {:ok, view, _html} = live(conn, "/chat")

      render_click(view, "remove-left")
      Phoenix.PubSub.broadcast(PubSub, topic, {ChatWidget, topic, "Hello"})

      refute has_element?(view, "#chat-left_chat")
      assert count_messages(view, "Hello") == 1
    end

    test "subscribes no process in the disconnected render", %{conn: conn, topic: topic} do
      {:ok, _view, _html} = live(conn, "/chat")

      Phoenix.PubSub.broadcast(PubSub, topic, {ChatWidget, topic, "Hello"})

      refute_received {ChatWidget, _topic, _message}
    end

    test "works in a LiveView that the router did not mount" do
      {:ok, view, _html} = live_isolated(build_conn(), GuideChatLive)

      view |> form("#chat-left_chat form", %{"message" => "Isolated"}) |> render_submit()

      assert count_messages(view, "Isolated") == 2

      conn = init_test_session(build_conn(), %{"child" => "guide-chat"})
      {:ok, parent, _html} = live(conn, "/nested")
      nested = find_live_child(parent, "nested")

      nested |> form("#chat-left_chat form", %{"message" => "Nested"}) |> render_submit()

      assert count_messages(nested, "Nested") == 2
    end
  end

  describe "the event handler" do
    test "can reply to an event" do
      {:ok, view, _html} = live(build_conn(), "/reply")

      render_hook(view, "probe:count", %{})

      assert_reply(view, %{count: 1})
    end

    test "raises FunctionClauseError in the widget for an event with no clause" do
      Process.flag(:trap_exit, true)
      {:ok, view, _html} = live(build_conn(), "/reply")

      # The reason of the exit contains the error in its Erlang form.
      # Exception.normalize/3 converts it into the Elixir exception.
      assert {{reason, stacktrace}, _call} = catch_exit(render_hook(view, "probe:unknown", %{}))

      assert %FunctionClauseError{module: ReplyLive, function: :handle_probe} =
               Exception.normalize(:error, reason, stacktrace)
    end

    test "sends each event to the LiveView after unroute_events/2" do
      {:ok, view, _html} = live(build_conn(), "/reply")

      render_click(view, "unroute")

      assert render_hook(view, "probe:count", %{}) =~ "Received by LiveView"
    end

    test "raises ArgumentError for a return value of another form" do
      Process.flag(:trap_exit, true)
      {:ok, view, _html} = live(build_conn(), "/reply")

      assert {{%ArgumentError{message: message}, _stacktrace}, _call} =
               catch_exit(render_hook(view, "probe:wrong", %{}))

      assert message =~ ~s(the event handler of the widget "probe" must return)
    end
  end
end
