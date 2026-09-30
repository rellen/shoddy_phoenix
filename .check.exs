[
  parallel: true,
  skipped: true,
  tools: [
    # phoenix_live_view is an optional dependency. This tool compiles the
    # project without that dependency, in a separate build directory. The
    # project must still compile, with no warning.
    {:no_optional_deps, "mix compile --no-optional-deps --warnings-as-errors",
     env: %{"MIX_BUILD_ROOT" => "_build/no_optional_deps"}}
  ]
]
