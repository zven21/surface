defmodule Surface.MixProject do
  use Mix.Project

  @version "0.1.0-rc.2"

  def project do
    [
      app: :surface,
      version: @version,
      elixir: "~> 1.8",
      description: "A component based library for Phoenix LiveView",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nimble_parsec, "~> 0.5 or ~> 1.0"},
      {:jason, "~> 1.0"},
      {:phoenix_live_view,
       git: "https://github.com/phoenixframework/phoenix_live_view.git",
       tag: "f986171cae03747366c3cd1c4f4fea047e1d7196"},
      {:earmark, "~> 1.3"},
      {:floki, "~> 0.25.0", only: :test},
      {:phoenix_ecto, "~> 4.0", only: :test},
      {:ecto, "~> 3.4.2", only: :test},
      {:ex_doc, ">= 0.19.0", only: :docs}
    ]
  end

  defp docs do
    [
      main: "Surface",
      source_ref: "v#{@version}",
      source_url: "https://github.com/msaraiva/surface"
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/msaraiva/surface"}
    }
  end
end
