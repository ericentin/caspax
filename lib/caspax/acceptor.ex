defmodule Caspax.Acceptor do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def prepare(preparer, proposer, ref, ballot_number, key) do
    send(preparer, {:prepare, proposer, ref, ballot_number, key})
  end

  def accept(preparer, proposer, ref, ballot_number, key, value) do
    send(preparer, {:accept, proposer, ref, ballot_number, key, value})
  end

  @doc false
  def init(_args) do
    parent = self()
    :pg2.join(__MODULE__.Acceptors, parent)
    Task.start_link(fn -> propose_and_join(parent) end)
    {:ok, %{}}
  end

  defp propose_and_join(parent) do
    case Caspax.Proposer.propose(nil, fn x -> x end) do
      {:ok, nil} ->
        :pg2.join(__MODULE__.Preparers, parent)

      {:error, _} ->
        propose_and_join(parent)
    end
  end

  @doc false
  def handle_info(
        {:prepare, proposer, ref, ballot_number, key},
        state
      ) do
    ballot = {ballot_number, node(proposer)}

    case state do
      %{^key => {promised, _accepted, _value}} when promised > ballot ->
        Caspax.Proposer.reply(proposer, ref, {:reject, promised, nil})
        {:noreply, state}

      %{^key => {_promised, accepted, _value}} when accepted > ballot ->
        Caspax.Proposer.reply(proposer, ref, {:reject, accepted, nil})
        {:noreply, state}

      %{^key => {_promised, accepted, value}} ->
        Caspax.Proposer.reply(proposer, ref, {:confirm, accepted, value})
        {:noreply, Map.put(state, key, {ballot, accepted, value})}

      _ ->
        Caspax.Proposer.reply(proposer, ref, {:confirm, nil, nil})
        {:noreply, Map.put(state, key, {ballot, nil, nil})}
    end
  end

  def handle_info(
        {:accept, proposer, ref, ballot_number, key, new_value},
        state
      ) do
    ballot = {ballot_number, node(proposer)}

    case state do
      %{^key => {promised, accepted, _value}} when promised > ballot or accepted > ballot ->
        Caspax.Proposer.reply(proposer, ref, :reject)
        {:noreply, state}

      _ ->
        Caspax.Proposer.reply(proposer, ref, :confirm)
        {:noreply, Map.put(state, key, {nil, ballot, new_value})}
    end
  end
end
