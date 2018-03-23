defmodule Caspax.BallotNumber do
  def new do
    :ets.new(Caspax.BallotNumber, [
      :public,
      :set,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])
  end

  def get_next do
    :ets.update_counter(
      Caspax.BallotNumber,
      Caspax.BallotNumber,
      1,
      {Caspax.BallotNumber, -1}
    )
  end

  def fast_forward(new_ballot_number) do
    curr = :ets.lookup_element(Caspax.BallotNumber, Caspax.BallotNumber, 2)
    diff = new_ballot_number - curr

    if diff > 0 do
      :ets.update_counter(Caspax.BallotNumber, Caspax.BallotNumber, diff)
    else
      curr
    end
  end
end
