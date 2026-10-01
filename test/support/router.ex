defmodule ShoddyPhoenix.Test.Router do
  @moduledoc false
  use Phoenix.Router, helpers: false

  import Phoenix.LiveView.Router

  alias ShoddyPhoenix.Test.AsyncLive
  alias ShoddyPhoenix.Test.ConnectedOnlyLive
  alias ShoddyPhoenix.Test.LostAssignLive
  alias ShoddyPhoenix.Test.PlaceholderLive
  alias ShoddyPhoenix.Test.ProbeHook
  alias ShoddyPhoenix.Test.ProbeLive
  alias ShoddyPhoenix.Test.SubscribeLive

  # Two routes go to ProbeLive, so a test can make a live navigation between
  # them.
  live_session :probe, on_mount: ProbeHook do
    live "/probe", ProbeLive
    live "/probe/again", ProbeLive
  end

  live_session :default do
    live "/placeholder", PlaceholderLive
    live "/lost-assign", LostAssignLive
    live "/async", AsyncLive
    live "/subscribe", SubscribeLive
    live "/connected-only", ConnectedOnlyLive
  end
end
