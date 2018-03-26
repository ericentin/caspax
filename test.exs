# {:ok, acceptor} = Caspax.Acceptor.start_link([])
# GenServer.stop(acceptor)
# :dbg.tracer()
# :dbg.p(:new_processes, :m)

{:ok, acceptor1} = Caspax.Acceptor.start_link(:acceptor1)
{:ok, acceptor2} = Caspax.Acceptor.start_link(:acceptor2)
{:ok, acceptor3} = Caspax.Acceptor.start_link(:acceptor3)
preparers = [acceptor1, acceptor2, acceptor3]
acceptors = preparers

IO.inspect(
  Caspax.Proposer.propose(:hello, fn x ->
    if is_nil(x) do
      {0, :world}
    else
      x
    end
  end),
  label: :initialize
)

IO.inspect(Enum.map(acceptors, &:sys.get_state(&1)))

{:ok, {version, _}} =
  IO.inspect(
    Caspax.Proposer.propose(:hello, fn x ->
      x
    end),
    label: :read
  )

IO.inspect(Enum.map(acceptors, &:sys.get_state(&1)))

new_version = version + 1

IO.inspect(
  {:ok, {^new_version, :world_updated}} =
    Caspax.Proposer.propose(:hello, fn x ->
      if match?({^version, _}, x) do
        {new_version, :world_updated}
      else
        x
      end
    end),
  label: :update
)

IO.inspect(Enum.map(acceptors, &:sys.get_state(&1)))

{:ok, {^new_version, :world_updated}} =
  IO.inspect(
    Caspax.Proposer.propose(:hello, fn x ->
      x
    end),
    label: :read
  )

IO.inspect(Enum.map(acceptors, &:sys.get_state(&1)))
