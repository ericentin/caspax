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
      get_next()
    rescue
      # the ets table already exists
      # so we return the name of the table as :ets.new/2 does
      ArgumentError -> __MODULE__
    end

    :ok
  end

  def get_next do
    :ets.update_counter(
      __MODULE__,
      __MODULE__,
      1,
      {__MODULE__, -2}
    )
  end

  def fast_forward(new_ballot_number) do
    # the following is a match spec that looks for two-tuple entries
    # (aka a counter) where the key is our key and the value is less
    # than what we are fast forwarding to.
    #
    # not pretty, but ensures an atomic update to prevent race conditions
    # between different processes trying to change the ballot number
    #
    # see http://erlang.org/doc/apps/erts/match_spec.html
    ms = [
      {
        {:"$1", :"$2"},
        [{:<, :"$2", {:const, new_ballot_number}}, {:"=:=", {:const, __MODULE__}, :"$1"}],
        [{{:"$1", {:const, new_ballot_number}}}]
      }
    ]

    case :ets.select_replace(__MODULE__, ms) do
      0 -> :ets.lookup_element(__MODULE__, __MODULE__, 2)
      _ -> new_ballot_number
    end
  end
end
