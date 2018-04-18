defmodule Caspax.BallotNumber do
  def init do
    try do
      :ets.new(__MODULE__, [
        :public,
        :set,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    rescue
      # the ets table already exists
      # so we return the name of the table as :ets.new/2 does
      ArgumentError -> __MODULE__
    end
  end

  def get_next do
    :ets.update_counter(
      __MODULE__,
      __MODULE__,
      1,
      {__MODULE__, -1}
    )
  end

  def fast_forward(new_ballot_number) do
    curr = :ets.lookup_element(__MODULE__, __MODULE__, 2)
    diff = new_ballot_number - curr

    if diff > 0 do
      :ets.update_counter(__MODULE__, __MODULE__, diff)
    else
      curr
    end
  end
end
