defmodule Caspax.Acceptor do
  use GenServer

  use Caspax.Logger

  def start_link(name \\ Module.concat(__MODULE__, node())) do
    GenServer.start_link(__MODULE__, {Atom.to_string(name)}, name: name)
  end

  def prepare(preparer, proposer, ref, ballot_number, key) do
    send(preparer, {:prepare, proposer, ref, ballot_number, key})
  end

  def accept(preparer, proposer, ref, ballot_number, key, value) do
    send(preparer, {:accept, proposer, ref, ballot_number, key, value})
  end

  @doc false
  def init({name}) do
    parent = self()
    trace(name, "Initializing.")
    :ok = :pg2.join(__MODULE__.Acceptors, parent)
    Task.start_link(fn -> propose_and_join(name, parent) end)
    {:ok, {name, %{}}}
  end

  defp propose_and_join(name, parent) do
    trace(name, "Attempting join propose...")

    case Caspax.Proposer.propose(nil, fn x -> x end) do
      {:ok, nil} ->
        trace(name, "Join proposal succeeded.")
        :ok = :pg2.join(__MODULE__.Preparers, parent)

      {:error, _reason} ->
        trace(name, "Join proposal failed: #{inspect(_reason)}, retrying...")
        propose_and_join(name, parent)
    end
  end

  @doc false
  def handle_info(
        {:prepare, proposer, ref, ballot_number, key},
        {name, data} = state
      ) do
    ballot = {ballot_number, node(proposer)}

    case data do
      %{^key => {promised, _accepted, _value}} when promised > ballot ->
        trace(
          name,
          "Rejecting prepare (due to greater promise) for key: #{inspect(key)}, ballot: #{
            inspect(ballot)
          }, promised: #{inspect(promised)}"
        )

        Caspax.Proposer.reply(proposer, ref, {:reject, promised, nil})
        {:noreply, state}

      %{^key => {_promised, accepted, _value}} when accepted > ballot ->
        trace(
          name,
          "Rejecting prepare (due to greater accepted) for key: #{inspect(key)}, ballot: #{
            inspect(ballot)
          }, accepted: #{inspect(accepted)}"
        )

        Caspax.Proposer.reply(proposer, ref, {:reject, accepted, nil})
        {:noreply, state}

      %{^key => {_promised, accepted, value}} ->
        trace(
          name,
          "Confirming prepare for key: #{inspect(key)}, promised: #{inspect(ballot)}, accepted: #{
            inspect(accepted)
          }, value: #{inspect(value)}"
        )

        Caspax.Proposer.reply(proposer, ref, {:confirm, accepted, value})
        {:noreply, {name, Map.put(data, key, {ballot, accepted, value})}}

      _ ->
        trace(
          name,
          "Confirming prepare for empty key: #{inspect(key)}, promised: #{inspect(ballot)}"
        )

        Caspax.Proposer.reply(proposer, ref, {:confirm, nil, nil})
        {:noreply, {name, Map.put(data, key, {ballot, nil, nil})}}
    end
  end

  def handle_info(
        {:accept, proposer, ref, ballot_number, key, new_value},
        {name, data} = state
      ) do
    ballot = {ballot_number, node(proposer)}

    case data do
      %{^key => {promised, accepted, _value}} when promised > ballot or accepted > ballot ->
        trace(
          name,
          "Rejecting accept for key: #{inspect(key)}, ballot: #{inspect(ballot)}, promised: #{
            inspect(promised)
          }, accepted: #{inspect(accepted)}, new_value: #{inspect(new_value)}"
        )

        Caspax.Proposer.reply(proposer, ref, :reject)
        {:noreply, state}

      _ ->
        trace(
          name,
          "Confirming accept for key: #{inspect(key)}, ballot: #{inspect(ballot)}, new_value: #{
            inspect(new_value)
          }"
        )

        Caspax.Proposer.reply(proposer, ref, :confirm)
        {:noreply, {name, Map.put(data, key, {nil, ballot, new_value})}}
    end
  end
end
