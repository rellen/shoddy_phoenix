defmodule ShoddyPhoenix.MixProject do
  use Mix.Project

  alias ShoddyPhoenix.LiveView.Subscriptions
  alias ShoddyPhoenix.LiveView.Widgets

  def project do
    [
      app: :shoddy_phoenix,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Small functions for tasks that occur frequently in Phoenix code.",
      name: "ShoddyPhoenix",
      source_url: "https://github.com/rellen/shoddy_phoenix",
      homepage_url: "https://rellen.github.io/shoddy_phoenix/",
      docs: docs(),
      dialyzer: [plt_local_path: "priv/plts"]
    ]
  end

  # The tests of ShoddyPhoenix.LiveView need an endpoint, a router and some
  # LiveViews. These modules are in test/support, and only the test
  # environment compiles them.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def cli do
    [preferred_envs: ["test.mutation": :test]]
  end

  defp aliases do
    [
      # Tell git to use the tracked hooks directory. Do not copy the file into
      # .git/hooks, because a copy does not change when a person changes the
      # tracked file.
      # Mix runs this command without a shell, so the command must be one
      # command with no operator.
      "hook.install": [
        "cmd git config core.hooksPath hooks"
      ],
      # Run mutation testing with muex. The command mix check does not run
      # this alias, so a mutation result cannot make a check fail. The option
      # --fail-at 0 stops a low score from making this alias fail. Each module
      # is small, and the default filter of muex skips a small module, so
      # --no-filter is necessary.
      "test.mutation": [
        "muex --no-filter --fail-at 0 --timeout 30000"
      ]
    ]
  end

  # The pages of `mix docs`. The groups follow Diátaxis. A tutorial is a
  # lesson, a how-to guide gives the steps of one task, a reference page gives
  # the facts, and an explanation gives the design and its reasons. The page of
  # each module is also a reference. See `docs/development.md`.
  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/tutorials/get-started.md",
        "docs/how-to/replace-a-cond-block-in-a-template.md",
        "docs/how-to/render-a-result-in-a-template.md",
        "docs/how-to/wrap-content-only-when-a-condition-is-true.md",
        "docs/how-to/show-a-message-for-an-empty-list.md",
        "docs/how-to/do-work-only-after-a-liveview-connects.md",
        "docs/explanation/design.md",
        "docs/development.md"
      ],
      groups_for_extras: [
        Tutorials: ~r"docs/tutorials/",
        "How-to guides": ~r"docs/how-to/",
        Reference: ~r"docs/reference/",
        Explanation: ~r"docs/explanation/",
        Development: ["docs/development.md"]
      ],
      groups_for_modules: [
        Components: [ShoddyPhoenix.ControlFlow],
        "LiveView sockets": [
          ShoddyPhoenix.LiveView,
          Subscriptions,
          Widgets
        ]
      ]
    ]
  end

  # Phoenix is the only required runtime dependency. phoenix_live_view is
  # optional. Read `CLAUDE.md` before you add a dependency.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.2", optional: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.12", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # Phoenix.LiveViewTest needs lazy_html to render a LiveView in a test.
      {:lazy_html, "~> 0.1.0", only: :test},
      {:doctor, "~> 0.23.0", only: :dev, runtime: false},
      {:ex_check, "~> 0.16.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:muex, "~> 0.11", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14.1", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
