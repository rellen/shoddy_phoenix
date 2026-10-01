defmodule ShoddyPhoenix.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.Component
  alias Phoenix.LiveComponent.CID
  alias Phoenix.LiveView.Lifecycle
  alias Phoenix.LiveView.Socket
  alias ShoddyPhoenix.LiveView
  alias ShoddyPhoenix.Test.Endpoint
  alias ShoddyPhoenix.Test.ParamsHookLive
  alias ShoddyPhoenix.Test.PubSub
  alias ShoddyPhoenix.Test.Router

  @endpoint Endpoint

  # The type checker of Elixir can warn about a literal that a test gives to
  # a function on purpose, such as a value that is not a socket. This helper
  # returns its argument, and the type checker cannot see through it.
  defp opaque(value), do: Process.get({__MODULE__, :unset}, value)

  # Phoenix.LiveView.connected?/1 is true for a socket with a transport
  # process. These sockets use that rule.
  defp connected_socket, do: %Socket{transport_pid: self()}
  defp disconnected_socket, do: %Socket{}

  # This helper sends a message to the test process, and it returns the
  # socket with a new assign. A test then knows that the function ran, and
  # that the result of the function is the return value.
  defp mark(socket) do
    send(self(), :ran)
    Component.assign(socket, :marked, true)
  end

  describe "when_connected/2" do
    test "calls the function and returns its result for a connected socket" do
      result = LiveView.when_connected(connected_socket(), &mark/1)

      assert result.assigns.marked
      assert_received :ran
    end

    test "returns the socket and does not call the function for a socket that is not connected" do
      socket = disconnected_socket()

      assert LiveView.when_connected(socket, &mark/1) === socket
      refute_received :ran
    end

    test "raises ArgumentError when the function does not return a socket" do
      message =
        "ShoddyPhoenix.LiveView.when_connected/2 needs a function that returns a socket. " <>
          "The function returned :ok. A call such as Phoenix.PubSub.subscribe/2 returns :ok, " <>
          "so return the socket after that call."

      assert_raise ArgumentError, message, fn ->
        LiveView.when_connected(connected_socket(), fn _socket -> opaque(:ok) end)
      end
    end

    test "raises FunctionClauseError for a value that is not a socket" do
      error = assert_raise FunctionClauseError, fn -> LiveView.when_connected(opaque(%{}), &mark/1) end
      assert {error.module, error.function} == {LiveView, :when_connected}
    end

    test "raises FunctionClauseError for a function of another arity" do
      assert_raise FunctionClauseError, fn ->
        LiveView.when_connected(connected_socket(), opaque(fn -> :ok end))
      end
    end
  end

  describe "when_not_connected/2" do
    test "calls the function and returns its result for a socket that is not connected" do
      result = LiveView.when_not_connected(disconnected_socket(), &mark/1)

      assert result.assigns.marked
      assert_received :ran
    end

    test "returns the socket and does not call the function for a connected socket" do
      socket = connected_socket()

      assert LiveView.when_not_connected(socket, &mark/1) === socket
      refute_received :ran
    end

    test "raises ArgumentError when the function does not return a socket" do
      assert_raise ArgumentError, ~r"^ShoddyPhoenix.LiveView.when_not_connected/2 needs a function", fn ->
        LiveView.when_not_connected(disconnected_socket(), fn _socket -> opaque(:ok) end)
      end
    end

    test "raises FunctionClauseError for a value that is not a socket" do
      error = assert_raise FunctionClauseError, fn -> LiveView.when_not_connected(opaque(%{}), &mark/1) end
      assert {error.module, error.function} == {LiveView, :when_not_connected}
    end

    test "raises FunctionClauseError for a function of another arity" do
      assert_raise FunctionClauseError, fn ->
        LiveView.when_not_connected(disconnected_socket(), opaque(fn -> :ok end))
      end
    end
  end

  describe "put_hook/4" do
    # LiveView keeps the hooks in the private data of the socket. A socket
    # with a router behaves as the socket of a LiveView that the router
    # mounted.
    defp hook_socket, do: %Socket{router: Router, private: %{lifecycle: %Lifecycle{}}}

    defp on_event(_event, _params, socket), do: {:cont, socket}

    test "replaces a hook with the same id and stage, where attach_hook/4 raises" do
      socket = LiveView.put_hook(hook_socket(), :hook, :handle_event, &on_event/3)

      assert %Socket{} = LiveView.put_hook(socket, :hook, :handle_event, &on_event/3)

      assert_raise ArgumentError, ~r/existing hook :hook already attached on :handle_event/, fn ->
        Phoenix.LiveView.attach_hook(socket, :hook, :handle_event, &on_event/3)
      end
    end

    test "accepts the arity of the table for each stage" do
      socket =
        hook_socket()
        |> LiveView.put_hook(:hook, :handle_event, fn _event, _params, socket -> {:cont, socket} end)
        |> LiveView.put_hook(:hook, :handle_params, fn _params, _uri, socket -> {:cont, socket} end)
        |> LiveView.put_hook(:hook, :handle_async, fn _key, _result, socket -> {:cont, socket} end)
        |> LiveView.put_hook(:hook, :handle_info, fn _message, socket -> {:cont, socket} end)
        |> LiveView.put_hook(:hook, :after_render, fn socket -> socket end)

      assert %Socket{} = socket
    end

    test "raises FunctionClauseError for a function of another arity" do
      two = opaque(fn _a, _b -> :ok end)
      three = opaque(fn _a, _b, _c -> :ok end)

      for {stage, fun} <- [
            handle_event: two,
            handle_params: two,
            handle_async: two,
            handle_info: three,
            after_render: two
          ] do
        assert_raise FunctionClauseError, fn -> LiveView.put_hook(hook_socket(), :hook, stage, fun) end
      end
    end

    test "raises FunctionClauseError for another stage or for a value that is not a socket" do
      assert_raise FunctionClauseError, fn ->
        LiveView.put_hook(hook_socket(), :hook, opaque(:mount), fn _socket -> :ok end)
      end

      assert_raise FunctionClauseError, fn ->
        LiveView.put_hook(opaque(%{}), :hook, :handle_info, fn _message, socket -> {:cont, socket} end)
      end
    end

    test "puts a replaced hook at the end of the order, with its new function" do
      {:ok, view, _html} = live(build_conn(), "/hook-order")

      render_click(view, "go")

      assert view |> element("#order") |> render() =~ ">second replacement<"
    end

    test "a :handle_params hook works only in a LiveView that the router mounted" do
      {:ok, _view, html} = live(build_conn(), "/params-hook")
      assert html =~ "hooked true"

      assert_raise RuntimeError, ~r/not mounted at the router/, fn ->
        live_isolated(build_conn(), ParamsHookLive)
      end

      conn = init_test_session(build_conn(), %{"child" => "params-hook"})

      assert_raise ArgumentError, ~r"handle_params/3 is not allowed on child LiveViews", fn ->
        get(conn, "/nested")
      end
    end

    test "raises ArgumentError for a :handle_info hook on the socket of a LiveComponent" do
      socket = %{hook_socket() | assigns: %{__changed__: %{}, myself: %CID{cid: 1}}}

      assert_raise ArgumentError, ~r/lifecycle hooks are not supported on stateful components/, fn ->
        LiveView.put_hook(socket, :hook, :handle_info, fn _message, socket -> {:cont, socket} end)
      end
    end
  end

  # These tests render LiveViews through a test endpoint. They check the
  # claims of the section "The two renders" of the documentation.
  describe "the two renders" do
    setup do
      %{conn: init_test_session(build_conn(), %{"test_pid" => self()})}
    end

    test "the disconnected render runs in the process of the request, and the connected render runs in another process",
         %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/probe")
      test_pid = self()

      for callback <- [:on_mount, :mount, :handle_params, :component_update] do
        assert_received {^callback, :not_connected, ^test_pid}
        assert_received {^callback, :connected, pid} when pid != test_pid
      end

      refute_received {_callback, _state, _pid}
    end

    test "a live navigation mounts the LiveView with a connected socket only", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/probe")
      flush()

      {:ok, _view, _html} = live_redirect(view, to: "/probe/again")

      assert_received {:mount, :connected, _pid}
      refute_received {_callback, :not_connected, _pid}
    end

    test "LiveView calls handle_event/3 and handle_info/2 only in the connected process", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/probe")
      flush()

      render_click(view, "probe")
      send(view.pid, :probe)
      render(view)

      assert_received {:handle_event, :connected, pid} when pid == view.pid
      assert_received {:handle_info, :connected, pid} when pid == view.pid
      refute_received {_callback, _state, _pid}
    end

    test "the connected render does not get the assigns of the disconnected render", %{conn: conn} do
      assert conn |> get("/lost-assign") |> html_response(200) =~ "Disconnected title"

      Process.flag(:trap_exit, true)

      assert {{%KeyError{key: :title}, _stacktrace}, _call} = catch_exit(live(conn, "/lost-assign"))
    end

    test "the example of the module subscribes only the process of the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/subscribe")

      Phoenix.PubSub.broadcast(PubSub, "messages", {:new_message, "Hello"})

      assert render(view) =~ "<p>Hello</p>"
      refute_received {:new_message, "Hello"}
    end

    test "the disconnected render raises KeyError for an assign that only when_connected/2 sets",
         %{conn: conn} do
      assert_raise KeyError, ~r/key :messages not found/, fn -> get(conn, "/connected-only") end
    end

    test "the example of when_not_connected/2 shows the placeholder only in the HTTP response",
         %{conn: conn} do
      static_html = conn |> get("/placeholder") |> html_response(200)
      assert static_html =~ "<p>Loading</p>"
      refute static_html =~ "Row one"

      {:ok, _view, html} = live(conn, "/placeholder")
      assert html =~ "<p>Row one</p><p>Row two</p>"
      refute html =~ "Loading"
    end

    test "assign_async/4 and start_async/4 start a task only for a connected socket", %{conn: conn} do
      assert conn |> get("/async") |> html_response(200) =~ "Loading data"

      {:ok, view, _html} = live(conn, "/async")

      assert render_async(view) =~ "Loaded"
      assert_receive {:start_async, true}
      assert_received {:assign_async, true}
      refute_received {:assign_async, false}
      refute_received {:start_async, false}
    end
  end

  # This helper removes each message from the mailbox of the test process. A
  # test then examines only the messages of its next step.
  defp flush do
    receive do
      _message -> flush()
    after
      0 -> :ok
    end
  end
end
