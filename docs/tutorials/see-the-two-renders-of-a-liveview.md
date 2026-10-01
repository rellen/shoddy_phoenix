# See the two renders of a LiveView

In this tutorial, you write a script with LiveViews that show headlines. The
headlines come from Phoenix.PubSub. Each process that subscribes to a topic
of PubSub receives each message of that topic.

You see that a LiveView mounts two times, and you find two problems that this
causes for a subscription. Then you fix the problems with
`ShoddyPhoenix.LiveView.when_connected/2` and
`ShoddyPhoenix.LiveView.Subscriptions`.

You need Elixir 1.19 or a later version, and git. The script uses
phoenix_playground, which runs a LiveView with no Phoenix application. If you
do not know `Mix.install/2`, do
[Get started with ShoddyPhoenix](get-started.md) first.

## Make the script

Make a new directory. In it, make the file `news.exs` with this code:

```elixir
Mix.install([
  {:phoenix_playground, "~> 0.1.9"},
  {:shoddy_phoenix, github: "rellen/shoddy_phoenix"}
])

Logger.configure(level: :warning)
ExUnit.start()

defmodule NewsCase do
  use ExUnit.CaseTemplate

  setup do
    start_supervised!({Phoenix.PubSub, name: News.PubSub})
    :ok
  end
end
```

The code does these steps:

- `Mix.install/2` gets phoenix_playground and ShoddyPhoenix. phoenix_playground
  also gets Phoenix LiveView.
- `Logger.configure/1` hides the log messages of Phoenix. The output then
  shows only the messages of the script.
- `ExUnit.start/1` starts ExUnit. When the script ends, ExUnit runs the
  tests of the script.
- Each test of this tutorial uses `NewsCase`. For each test, `NewsCase`
  starts a PubSub server with the name `News.PubSub`.

Run the script:

```sh
elixir news.exs
```

The first run gets and compiles the dependencies, so it is slow. The output
ends with `0 tests, 0 failures`.

phoenix_playground has live reload, which loads a page again when its file
changes. On Linux, live reload needs `inotify-tools`. Without it, the script
logs an error about `inotify-tools`. The tests do not need live reload, so
you can ignore that error.

## Write a LiveView

Add a LiveView and its test to the end of the script. The LiveView subscribes
to the topic `"headlines"` when it mounts, and it shows each headline that it
receives. It also prints a line each time that it mounts:

```elixir
defmodule FirstNewsLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    IO.puts("FirstNewsLive.mount/3 runs in #{inspect(self())}. Connected: #{connected?(socket)}.")
    Phoenix.PubSub.subscribe(News.PubSub, "headlines")
    {:ok, assign(socket, :headlines, [])}
  end

  def handle_info({:headline, headline}, socket) do
    {:noreply, update(socket, :headlines, &(&1 ++ [headline]))}
  end

  def render(assigns) do
    ~H"""
    <ul>
      <li :for={headline <- @headlines}>{headline}</li>
    </ul>
    """
  end
end

defmodule FirstNewsLiveTest do
  use NewsCase
  use PhoenixPlayground.Test, live: FirstNewsLive

  test "the process of the HTTP request also receives the headline" do
    IO.puts("The test runs in #{inspect(self())}.")
    {:ok, view, _html} = live(build_conn(), "/")

    Phoenix.PubSub.broadcast(News.PubSub, "headlines", {:headline, "Rain tomorrow"})

    assert render(view) =~ "<li>Rain tomorrow</li>"
    assert_received {:headline, "Rain tomorrow"}
  end
end
```

`use PhoenixPlayground.Test` gives the test the functions of
`Phoenix.LiveViewTest`. `live/2` requests the page of the LiveView over HTTP.
Then it connects to the LiveView, as a browser does.

Run the script again. The output is similar to this text:

```text
The test runs in #PID<0.250.0>.
FirstNewsLive.mount/3 runs in #PID<0.250.0>. Connected: false.
FirstNewsLive.mount/3 runs in #PID<0.273.0>. Connected: true.
.
Finished in 0.3 seconds (0.1s on load, 0.00s async, 0.1s sync)
1 test, 0 failures
```

Your numbers of the processes can be different. `mount/3` runs two times:

1. The HTTP request renders the page. `mount/3` runs in the process of the
   request, with a socket that is not connected. In a test, the process of
   the request is the process of the test.
2. Then the LiveView connects. `mount/3` runs again in a new process, with a
   connected socket.

Both mounts subscribe. Thus the process of the HTTP request also receives the
headline, and `assert_received` succeeds. Nothing in that process uses the
headline.

## Subscribe only in the connected mount

Add a second LiveView and its test to the end of the script.
`ShoddyPhoenix.LiveView.when_connected/2` calls `subscribe/1` only when the
socket is connected:

```elixir
defmodule GuardedNewsLive do
  use Phoenix.LiveView

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:headlines, [])
      |> LiveView.when_connected(&subscribe/1)

    {:ok, socket}
  end

  defp subscribe(socket) do
    Phoenix.PubSub.subscribe(News.PubSub, "headlines")
    socket
  end

  def handle_info({:headline, headline}, socket) do
    {:noreply, update(socket, :headlines, &(&1 ++ [headline]))}
  end

  def render(assigns) do
    ~H"""
    <ul>
      <li :for={headline <- @headlines}>{headline}</li>
    </ul>
    """
  end
end

defmodule GuardedNewsLiveTest do
  use NewsCase
  use PhoenixPlayground.Test, live: GuardedNewsLive

  test "only the process of the LiveView receives the headline" do
    {:ok, view, _html} = live(build_conn(), "/")

    Phoenix.PubSub.broadcast(News.PubSub, "headlines", {:headline, "Rain tomorrow"})

    assert render(view) =~ "<li>Rain tomorrow</li>"
    refute_received {:headline, _headline}
  end
end
```

The function of `when_connected/2` must return the socket.
`Phoenix.PubSub.subscribe/2` returns `:ok`, so `subscribe/1` returns the
socket after that call.

Run the script again. The output ends with `2 tests, 0 failures`.
`refute_received` succeeds, so the process of the HTTP request did not
subscribe.

## Add a second part

A LiveView often has several parts, and two parts can need the same topic.
Add a LiveView with two parts and its test to the end of the script. The
parts are a list of headlines and a counter, and each part subscribes:

```elixir
defmodule TwoPartNewsLive do
  use Phoenix.LiveView

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    socket =
      socket
      |> add_headline_list()
      |> add_counter()

    {:ok, socket}
  end

  # The headline list shows each headline.
  defp add_headline_list(socket) do
    socket
    |> assign(:headlines, [])
    |> LiveView.when_connected(&subscribe/1)
  end

  # The counter counts the headlines.
  defp add_counter(socket) do
    socket
    |> assign(:count, 0)
    |> LiveView.when_connected(&subscribe/1)
  end

  defp subscribe(socket) do
    Phoenix.PubSub.subscribe(News.PubSub, "headlines")
    socket
  end

  def handle_info({:headline, headline}, socket) do
    socket =
      socket
      |> update(:headlines, &(&1 ++ [headline]))
      |> update(:count, &(&1 + 1))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <p>Headlines: {@count}</p>
    <ul>
      <li :for={headline <- @headlines}>{headline}</li>
    </ul>
    """
  end
end

defmodule TwoPartNewsLiveTest do
  use NewsCase
  use PhoenixPlayground.Test, live: TwoPartNewsLive

  test "each headline arrives two times" do
    {:ok, view, _html} = live(build_conn(), "/")

    Phoenix.PubSub.broadcast(News.PubSub, "headlines", {:headline, "Rain tomorrow"})

    html = render(view)
    assert html =~ "<p>Headlines: 2</p>"
    assert html =~ "<li>Rain tomorrow</li><li>Rain tomorrow</li>"
  end
end
```

Run the script again. The output ends with `3 tests, 0 failures`. The test
shows the problem: one broadcast gives two headlines. Each call of
`Phoenix.PubSub.subscribe/2` adds a subscription, so the process receives
each message two times.

## Give each part its own owner

`ShoddyPhoenix.LiveView.Subscriptions.subscribe/4` records an owner for each
part. The process subscribes only for the first owner of a topic, so it
receives each message one time. Add the last LiveView and its test to the end
of the script:

```elixir
defmodule NewsLive do
  use Phoenix.LiveView

  alias ShoddyPhoenix.LiveView.Subscriptions

  def mount(_params, _session, socket) do
    socket =
      socket
      |> add_headline_list()
      |> add_counter()

    {:ok, socket}
  end

  # The headline list shows each headline.
  defp add_headline_list(socket) do
    socket
    |> assign(:headlines, [])
    |> Subscriptions.subscribe(News.PubSub, "headlines", :headline_list)
  end

  # The counter counts the headlines.
  defp add_counter(socket) do
    socket
    |> assign(:count, 0)
    |> Subscriptions.subscribe(News.PubSub, "headlines", :counter)
  end

  def handle_info({:headline, headline}, socket) do
    socket =
      socket
      |> update(:headlines, &(&1 ++ [headline]))
      |> update(:count, &(&1 + 1))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <p>Headlines: {@count}</p>
    <ul>
      <li :for={headline <- @headlines}>{headline}</li>
    </ul>
    """
  end
end

defmodule NewsLiveTest do
  use NewsCase
  use PhoenixPlayground.Test, live: NewsLive

  test "each headline arrives one time, and only in the LiveView" do
    {:ok, view, _html} = live(build_conn(), "/")

    Phoenix.PubSub.broadcast(News.PubSub, "headlines", {:headline, "Rain tomorrow"})

    assert render(view) =~ "<p>Headlines: 1</p>"
    refute_received {:headline, _headline}
  end
end
```

`Subscriptions.subscribe/4` also does nothing for a socket that is not
connected. Thus `NewsLive` needs no `when_connected/2`.

Run the script again. The output ends with `4 tests, 0 failures`.

## Next steps

You saw the two renders of a LiveView. You found a subscription in the
process of the HTTP request and a message that arrived two times, and you
fixed both.

- The page of `ShoddyPhoenix.LiveView` describes the two renders. It also
  tells when only one render occurs, for example after a live navigation.
- [Do work only after a LiveView connects](../how-to/do-work-only-after-a-liveview-connects.md)
  gives the steps for a LiveView of an application.
- [Build a widget with lifecycle hooks](../how-to/build-a-widget-with-lifecycle-hooks.md)
  builds a chat widget with `ShoddyPhoenix.LiveView.Subscriptions` and
  `ShoddyPhoenix.LiveView.Widgets`.
- `PhoenixPlayground.start/1` shows a LiveView of a script in a browser. The
  documentation of phoenix_playground tells more.
