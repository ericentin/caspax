{:ok, acceptor1} = Caspax.Acceptor.start_link([])
{:ok, acceptor2} = Caspax.Acceptor.start_link([])
{:ok, acceptor3} = Caspax.Acceptor.start_link([])
preparers = [acceptor1, acceptor2, acceptor3]
acceptors = preparers

IO.inspect(
  Caspax.Proposer.propose(preparers, acceptors, :hello, fn x ->
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
    Caspax.Proposer.propose(preparers, acceptors, :hello, fn x ->
      x
    end),
    label: :read
  )

IO.inspect(Enum.map(acceptors, &:sys.get_state(&1)))

IO.inspect(
  Caspax.Proposer.propose(preparers, acceptors, :hello, fn x ->
    if match?({^version, _}, x) do
      {version + 1, :world_updated}
    else
      x
    end
  end),
  label: :update
)

IO.inspect(Enum.map(acceptors, &:sys.get_state(&1)))

{:ok, {version, _}} =
  IO.inspect(
    Caspax.Proposer.propose(preparers, acceptors, :hello, fn x ->
      x
    end),
    label: :read
  )

IO.inspect(Enum.map(acceptors, &:sys.get_state(&1)))
