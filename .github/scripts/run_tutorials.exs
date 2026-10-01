# This script runs the code of each tutorial in docs/tutorials. A tutorial is
# one script for Mix.install. The script puts the Elixir code blocks of the
# tutorial together in their order, and it runs the result with `elixir`.
#
# A code block can show an earlier version of code that a later block
# replaces. Put this line in front of the earlier block:
#
#     <!-- tutorial: earlier version -->
#
# Put this line in front of the block that replaces it:
#
#     <!-- tutorial: replaces the earlier version -->
#
# The script then puts the later block at the place of the earlier block.
#
# The tutorials get ShoddyPhoenix from GitHub. This script uses the code of
# this repository in its place, so a tutorial runs against the change that the
# workflow checks.
#
# The arguments are the paths of the tutorials. With no argument, the script
# runs each tutorial in docs/tutorials. The script exits with the status 1 if
# one tutorial fails, or if it finds no tutorial in docs/tutorials. A check
# with no tutorial checks nothing, so it must not succeed.

defmodule RunTutorials do
  @moduledoc false

  @root Path.expand("../..", __DIR__)
  @github_dep ~s({:shoddy_phoenix, github: "rellen/shoddy_phoenix"})
  @earlier "<!-- tutorial: earlier version -->"
  @replacement "<!-- tutorial: replaces the earlier version -->"

  def main([]) do
    case Path.wildcard(Path.join(@root, "docs/tutorials/*.md")) do
      [] ->
        IO.puts("The script found no tutorial in docs/tutorials.")
        System.halt(1)

      paths ->
        main(paths)
    end
  end

  def main(paths) do
    failed = Enum.reject(paths, &run/1)

    if failed == [] do
      IO.puts("Each tutorial succeeded.")
    else
      IO.puts("These tutorials failed: #{Enum.join(failed, ", ")}")
      System.halt(1)
    end
  end

  defp run(path) do
    IO.puts("The script runs the tutorial #{path}.")
    name = Path.basename(path, ".md")
    dir = Path.join([System.tmp_dir!(), "shoddy_phoenix_tutorials", name])
    File.mkdir_p!(dir)
    file = Path.join(dir, name <> ".exs")
    File.write!(file, path |> File.read!() |> script(path))

    {_output, status} = System.cmd("elixir", [file], cd: dir, stderr_to_stdout: true, into: IO.stream())

    if status == 0 do
      IO.puts("The tutorial #{path} succeeded.")
      true
    else
      IO.puts("The tutorial #{path} failed with the exit status #{status}.")
      false
    end
  end

  # Puts the code blocks together, and puts the code of this repository in
  # place of the dependency on GitHub.
  defp script(markdown, path) do
    code =
      markdown
      |> blocks()
      |> assemble(path)
      |> Enum.join("\n")

    if length(String.split(code, @github_dep)) != 2 do
      raise "#{path} must contain #{@github_dep} one time, in its call of Mix.install/1."
    end

    String.replace(code, @github_dep, "{:shoddy_phoenix, path: #{inspect(@root)}}")
  end

  # Returns each Elixir code block, with its kind. The kind comes from the
  # last line with text in front of the block.
  defp blocks(markdown) do
    {blocks, _previous, nil} =
      markdown
      |> String.split("\n")
      |> Enum.reduce({[], "", nil}, fn
        "```elixir", {blocks, previous, nil} -> {blocks, previous, {kind(previous), []}}
        "```", {blocks, _previous, {kind, lines}} -> {[{kind, Enum.reverse(lines)} | blocks], "```", nil}
        line, {blocks, previous, {kind, lines}} -> {blocks, previous, {kind, [line | lines]}}
        line, {blocks, previous, nil} -> {blocks, if(String.trim(line) == "", do: previous, else: line), nil}
      end)

    blocks
    |> Enum.reverse()
    |> Enum.map(fn {kind, lines} -> {kind, Enum.join(lines, "\n")} end)
  end

  defp kind(@earlier), do: :earlier
  defp kind(@replacement), do: :replacement
  defp kind(_line), do: :step

  # Puts each replacement at the place of the earlier version that it
  # replaces, in the order of the earlier versions.
  defp assemble(blocks, path) do
    {parts, open} =
      Enum.reduce(blocks, {[], []}, fn
        {:step, code}, {parts, open} ->
          {parts ++ [code], open}

        {:earlier, _code}, {parts, open} ->
          {parts ++ [nil], open ++ [length(parts)]}

        {:replacement, code}, {parts, [index | open]} ->
          {List.replace_at(parts, index, code), open}

        {:replacement, _code}, {_parts, []} ->
          raise "#{path} has a replacement with no earlier version in front of it."
      end)

    if open != [] do
      raise "#{path} has an earlier version with no replacement."
    end

    parts
  end
end

RunTutorials.main(System.argv())
