# The tests of ShoddyPhoenix.LiveView render LiveViews through this endpoint.
# The endpoint needs a secret to sign the session of each LiveView.
Application.put_env(:shoddy_phoenix, ShoddyPhoenix.Test.Endpoint,
  secret_key_base: String.duplicate("shoddy_phoenix_test", 4),
  live_view: [signing_salt: "shoddy_phoenix_test"],
  render_errors: [formats: [html: ShoddyPhoenix.Test.ErrorHTML], layout: false]
)

{:ok, _pid} = ShoddyPhoenix.Test.Endpoint.start_link()

# The example of ShoddyPhoenix.LiveView subscribes to a topic of this PubSub
# server.
{:ok, _pid} = Supervisor.start_link([{Phoenix.PubSub, name: ShoddyPhoenix.Test.PubSub}], strategy: :one_for_one)

# The LiveViews of the tests write log messages, and one test makes a
# LiveView crash. ExUnit shows the log of a test only when the test fails.
ExUnit.start(capture_log: true)
