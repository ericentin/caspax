# Caspax

An Elixir implementation of the CASPaxos distributed compare-and-set KV.

Currently incomplete, but the main portion of the protocol is implemented for erlang nodes. Test with `mix run test.exs`.

Related reading:
https://arxiv.org/abs/1802.07000
https://github.com/peterbourgon/caspaxos
https://github.com/tschottdorf/caspaxos-tla

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `caspax` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:caspax, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/caspax](https://hexdocs.pm/caspax).
