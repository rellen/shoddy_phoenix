{ pkgs, lib, ... }:

{
  languages.erlang = {
    enable = true;
    package = pkgs.beam.interpreters.erlang_28;
  };
  languages.elixir = {
    enable = true;
    package = pkgs.beam.packages.erlang_28.elixir_1_19;
  };
}
