defmodule Caspax.Application do
  use Application

  def start(_type, _args) do
    Caspax.BallotNumber.init()
    :pg2.create(Caspax.Acceptor.Preparers)
    :pg2.create(Caspax.Acceptor.Acceptors)

    children = []

    opts = [strategy: :one_for_one, name: Caspax.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
