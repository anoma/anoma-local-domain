# IndexerWeb

Steps for Running:

1. You need to set up the envio indexer https://github.com/anoma/anoma-beta-pa-indexer
To do this clone the repo, and then run pnpx envio dev (you will need to have everything required to set up envio) https://docs.envio.dev/docs/HyperIndex/getting-started
2. Set environmental variables (they can be arbitrary)
These set up the local domain node which will run the poller
3. Run this application (iex -S mix or -Sname or whatever you prefer)
It should now be indexing events and spitting out logs
4. Run the curl scripts to test that it is running in a separate shell
This will add keys to the indexer and retrieve data using the JSON API


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `indexer_web` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:indexer_web, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/indexer_web>.

