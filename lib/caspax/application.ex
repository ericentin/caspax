defmodule Caspax.Application do
  use Application

  def start(_type, _args) do
    Caspax.BallotNumber.new()

    children = []
    opts = [strategy: :one_for_one, name: Caspax.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
