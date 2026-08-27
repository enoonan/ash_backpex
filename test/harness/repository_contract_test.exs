defmodule AshBackpex.RepositoryContractTest do
  use ExUnit.Case, async: true

  @documents [
               "AGENTS.md",
               "CHANGELOG.md",
               "CONTRIBUTING.md",
               "README.md",
               "usage-rules.md"
             ] ++
               Path.wildcard("docs/**/*.md") ++
               Path.wildcard("guides/**/*.md")

  test "repository documentation has no broken local links" do
    failures =
      for document <- @documents,
          target <- markdown_targets(File.read!(document)),
          local_target?(target),
          failure = link_failure(document, target),
          not is_nil(failure),
          do: failure

    assert failures == [],
           "Broken repository documentation links:\n" <> Enum.join(failures, "\n")
  end

  test "the completion alias contains every repository gate" do
    aliases = Mix.Project.config()[:aliases]

    assert aliases[:ci] == [
             "format --check-formatted",
             "compile --warnings-as-errors",
             "credo --strict",
             "docs --warnings-as-errors",
             "test",
             "demo.check"
           ]

    assert aliases[:"demo.check"] == [
             "cmd --cd demo env MIX_ENV=dev mix deps.get --check-locked",
             "cmd --cd demo env MIX_ENV=dev mix compile --warnings-as-errors"
           ]
  end

  test "GitHub Actions invokes the local completion contract" do
    workflow = File.read!(".github/workflows/elixir.yml")

    assert workflow =~ ~r/^\s*run:\s+mix ci\s*$/m,
           ".github/workflows/elixir.yml must invoke mix ci instead of duplicating checks"
  end

  test "the demo consumes the repository-local AshBackpex package" do
    demo_project = File.read!("demo/mix.exs")

    assert demo_project =~ ~r/{:ash_backpex,\s*path:\s*"\.\.\/"/,
           "demo/mix.exs must keep the repository-local ash_backpex path dependency"
  end

  test "the demo seeds a recursive embedded article and checks pending migrations" do
    seeds = File.read!("demo/priv/repo/seeds.exs")
    endpoint = File.read!("demo/lib/demo_web/endpoint.ex")

    assert seeds =~ "title: \"Introduction\""
    assert seeds =~ "title: \"Next steps\""
    assert seeds =~ "heading: \"Why Ash?\""
    assert seeds =~ "heading: \"Framework guide\""
    assert seeds =~ "target: %{kind: :internal"
    assert seeds =~ "target: %{kind: :external"

    assert endpoint =~ "plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :demo)"
  end

  defp markdown_targets(markdown) do
    ~r/!?\[[^\]]*\]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)/
    |> Regex.scan(markdown, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim(&1, "<>"))
  end

  defp local_target?(target) do
    not String.starts_with?(target, ["#", "//"]) and is_nil(URI.parse(target).scheme)
  end

  defp link_failure(document, target) do
    [path | fragment] = String.split(target, "#", parts: 2)
    resolved = resolve_target(document, URI.decode(path))

    cond do
      not File.exists?(resolved) ->
        "#{document}: #{target} resolves to missing #{Path.relative_to_cwd(resolved)}"

      fragment == [] or File.dir?(resolved) ->
        nil

      heading_anchor?(resolved, URI.decode(hd(fragment))) ->
        nil

      true ->
        "#{document}: #{target} references a missing heading in #{Path.relative_to_cwd(resolved)}"
    end
  end

  defp resolve_target(document, target) do
    document
    |> Path.expand()
    |> Path.dirname()
    |> Path.join(target)
    |> Path.expand()
  end

  defp heading_anchor?(path, expected_anchor) do
    path
    |> File.read!()
    |> then(&Regex.scan(~r/^#+\s+(.+)$/m, &1, capture: :all_but_first))
    |> List.flatten()
    |> Enum.map(&heading_anchor/1)
    |> Enum.member?(expected_anchor)
  end

  defp heading_anchor(heading) do
    heading
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s-]/u, "")
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
  end
end
