# This script reads the JSON report of muex and writes a summary for GitHub
# Actions. It also writes a warning annotation for each mutant that survives.
# The script always exits with the status 0, so it cannot make a check fail.
#
# The first argument is the path of the report. An optional second argument
# is the path of a file. The script writes the same summary into that file,
# and the workflow posts that file as a comment on the pull request.

defmodule MuexSummary do
  @moduledoc false

  def run([path]), do: run([path, nil])

  def run([path, copy]) do
    Process.put(:copy, copy)

    case File.read(path) do
      {:ok, json} -> report(JSON.decode!(json))
      {:error, _reason} -> no_report()
    end
  end

  defp report(%{"summary" => summary, "mutations" => mutations}) do
    survived = Enum.filter(mutations, &(&1["status"] == "survived"))

    write_summary("""
    ## Mutation testing

    This check reports the result only. It does not make a check fail.

    | Result | Count |
    |---|---|
    | Killed | #{summary["killed"]} |
    | Survived | #{summary["survived"]} |
    | Invalid | #{summary["invalid"]} |
    | Timeout | #{summary["timeout"]} |
    | Equivalent | #{summary["equivalent"]} |
    | Total | #{summary["total"]} |

    Mutation score: #{summary["mutation_score_low"]}%

    Do not trust the invalid count. Muex sometimes reports a mutant as invalid,
    although the mutant compiles and the tests kill it.
    #{survived_section(survived)}
    """)

    Enum.each(survived, &annotate/1)
  end

  defp survived_section([]), do: "\nNo mutant survived.\n"

  defp survived_section(survived) do
    rows =
      Enum.map_join(survived, "\n", fn m ->
        "| `#{m["location"]["file"]}:#{m["location"]["line"]}` | #{m["description"]} |"
      end)

    """

    ### Mutants that survived

    Each mutant below shows a gap in the tests.

    | Location | Change |
    |---|---|
    #{rows}
    """
  end

  defp annotate(mutant) do
    file = escape_property(mutant["location"]["file"])
    line = mutant["location"]["line"]
    message = escape_data("A mutant survived: #{mutant["description"]}")
    IO.puts("::warning file=#{file},line=#{line}::#{message}")
  end

  defp no_report do
    write_summary("""
    ## Mutation testing

    Muex did not write a report. Examine the log of the step that runs muex.
    """)

    IO.puts("::warning::Muex did not write a report.")
  end

  defp write_summary(text) do
    case System.get_env("GITHUB_STEP_SUMMARY") do
      nil -> IO.write(text)
      file -> File.write!(file, text, [:append])
    end

    case Process.get(:copy) do
      nil -> :ok
      copy -> File.write!(copy, text)
    end
  end

  defp escape_data(text) do
    text
    |> String.replace("%", "%25")
    |> String.replace("\r", "%0D")
    |> String.replace("\n", "%0A")
  end

  defp escape_property(text) do
    text
    |> escape_data()
    |> String.replace(":", "%3A")
    |> String.replace(",", "%2C")
  end
end

MuexSummary.run(System.argv())
