[
  import_deps: [:phoenix],
  plugins: [Quokka],
  inputs: [
    "{mix,.formatter,.check,.credo,.doctor}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    ".github/**/*.exs"
  ]
]
