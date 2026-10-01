defmodule ShoddyPhoenix.LiveViewPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Phoenix.Component
  alias Phoenix.LiveView.Socket
  alias ShoddyPhoenix.LiveView

  # Phoenix.LiveView.connected?/1 is true for a socket with a transport
  # process. This generator makes connected sockets and sockets that are not
  # connected, with some random assigns. LiveView reserves some assign keys,
  # such as :flash, so the generator uses a fixed list of keys.
  defp socket do
    gen all(
          connected? <- boolean(),
          assigns <- list_of(tuple({member_of([:count, :name, :rows, :title]), integer()}))
        ) do
      transport_pid = if connected?, do: self()
      Component.assign(%Socket{transport_pid: transport_pid}, assigns)
    end
  end

  property "only one of the two functions calls its function, and the other assigns stay the same" do
    check all(socket <- socket()) do
      result =
        socket
        |> LiveView.when_connected(&Component.assign(&1, :shoddy_branch, :connected))
        |> LiveView.when_not_connected(&Component.assign(&1, :shoddy_branch, :not_connected))

      expected = if Phoenix.LiveView.connected?(socket), do: :connected, else: :not_connected
      assert result.assigns.shoddy_branch == expected

      assert Map.drop(result.assigns, [:shoddy_branch, :__changed__]) ==
               Map.delete(socket.assigns, :__changed__)
    end
  end

  property "each function returns the socket unchanged when it does not call its function" do
    check all(socket <- socket()) do
      skipped =
        if Phoenix.LiveView.connected?(socket),
          do: LiveView.when_not_connected(socket, &Component.assign(&1, :shoddy_branch, true)),
          else: LiveView.when_connected(socket, &Component.assign(&1, :shoddy_branch, true))

      assert skipped === socket
    end
  end
end
