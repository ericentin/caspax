defmodule Caspax.Proposer do
  use Caspax.Logger

  def query(key, timeout \\ 1_000) do
    propose(key, fn x -> x end, timeout)
  end

  def propose(
        key,
        fun,
        timeout \\ 1_000
      ) do
    preparers = :pg2.get_members(Caspax.Acceptor.Preparers)
    ballot_number = Caspax.BallotNumber.get_next()

    quorum =
      case length(preparers) do
        0 -> 0
        1 -> 1
        other -> div(other, 2) + 1
      end

    trace(
      inspect(self()),
      "Preparing key: #{inspect(key)}, with ballot number: #{ballot_number} and quorum: #{quorum} to preparers: #{
        inspect(preparers)
      }"
    )

    preparers
    |> reply_stream(
      timeout,
      &Caspax.Acceptor.prepare(&1, &2, &3, ballot_number, key)
    )
    |> collect_prepare_responses(quorum)
    |> finish_prepare(timeout, ballot_number, key, fun)
  end

  @doc false
  def reply(proposer_proxy, ref, value) do
    send(proposer_proxy, {ref, value})
  end

  defp reply_stream([], _timeout, _send_fun) do
    []
  end

  defp reply_stream(acceptors, timeout, send_fun) do
    Stream.resource(
      fn ->
        ref = make_ref()
        parent = self()

        {:ok, proxy} =
          Task.start_link(fn ->
            proxy = self()
            Enum.each(acceptors, &send_fun.(&1, proxy, ref))

            Stream.repeatedly(fn ->
              receive do
                {^ref, _} = msg ->
                  send(parent, msg)

                {^ref, :shutdown, parent} ->
                  send(parent, {ref, :shutting_down})
                  exit(:normal)
              end
            end)
            |> Stream.run()
          end)

        {ref, proxy, System.convert_time_unit(timeout, :millisecond, :native)}
      end,
      fn {ref, proxy, remaining_time} ->
        start_time = System.monotonic_time()

        remaining_time_in_millisecond =
          System.convert_time_unit(remaining_time, :native, :millisecond)

        receive do
          {^ref, _} = msg ->
            {[{:ok, msg}], {ref, proxy, remaining_time - (System.monotonic_time() - start_time)}}
        after
          remaining_time_in_millisecond -> {:halt, {ref, proxy, 0}}
        end
      end,
      fn {ref, proxy, _timeout_remaining} ->
        send(proxy, {ref, :shutdown, self()})

        receive do
          {^ref, :shutting_down} -> :ok
        end

        flush_remaining(ref)
      end
    )
  end

  defp flush_remaining(ref) do
    receive do
      {^ref, _} -> flush_remaining(ref)
    after
      0 -> :ok
    end
  end

  defp collect_prepare_responses(responses, quorum_left) do
    Enum.reduce_while(responses, {nil, nil, nil, quorum_left}, fn
      {:ok, {_, {:confirm, remote_ballot, remote_value}}},
      {_value, biggest_confirm, biggest_reject, 1}
      when remote_ballot > biggest_confirm ->
        {:halt, {remote_value, remote_ballot, biggest_reject, 0}}

      {:ok, {_, {:confirm, remote_ballot, remote_value}}},
      {_value, biggest_confirm, biggest_reject, quorum_left}
      when remote_ballot > biggest_confirm ->
        {:cont, {remote_value, remote_ballot, biggest_reject, quorum_left - 1}}

      {:ok, {_, {:confirm, _remote_ballot, _remote_value}}},
      {value, biggest_confirm, biggest_reject, 1} ->
        {:halt, {value, biggest_confirm, biggest_reject, 0}}

      {:ok, {_, {:confirm, _remote_ballot, _remote_value}}},
      {value, biggest_confirm, biggest_reject, quorum_left} ->
        {:cont, {value, biggest_confirm, biggest_reject, quorum_left - 1}}

      {:ok, {_, {:reject, remote_ballot, _remote_value}}},
      {value, biggest_confirm, biggest_reject, quorum_left}
      when remote_ballot > biggest_reject ->
        {:cont, {value, biggest_confirm, remote_ballot, quorum_left}}

      _, acc ->
        {:cont, acc}
    end)
  end

  defp finish_prepare(
         {_value, _biggest_confirm, {highest_ballot_number, _preparer}, quorum},
         _,
         _,
         _,
         _
       )
       when quorum > 0 do
    trace(
      inspect(self()),
      "Prepare failed with rejection(s), quorum_remaing: #{quorum}, new highest ballot: #{
        highest_ballot_number
      } from #{_preparer}"
    )

    Caspax.BallotNumber.fast_forward(highest_ballot_number)
    {:error, :prepare_failed}
  end

  defp finish_prepare(
         {_value, _biggest_confirm, _biggest_reject, quorum},
         _,
         _,
         _,
         _
       )
       when quorum > 0 do
    trace(inspect(self()), "Prepare failed without rejection, quorum remaining: #{quorum}")
    {:error, :prepare_failed}
  end

  defp finish_prepare(
         {value, _biggest_confirm, _biggest_reject, _quorum},
         timeout,
         ballot_number,
         key,
         fun
       ) do
    trace(
      inspect(self()),
      "Prepare succeded for key: #{inspect(key)}, with ballot number: #{ballot_number}, current value: #{
        inspect(value)
      }"
    )

    value = fun.(value)
    acceptors = :pg2.get_members(Caspax.Acceptor.Acceptors)

    quorum = div(length(acceptors), 2) + 1

    trace(
      inspect(self()),
      "Accepting key: #{inspect(key)}, with new value: #{inspect(value)}, ballot number: #{
        ballot_number
      } and quorum: #{quorum} to acceptors: #{inspect(acceptors)}"
    )

    acceptors
    |> reply_stream(timeout, &Caspax.Acceptor.accept(&1, &2, &3, ballot_number, key, value))
    |> collect_accept_responses(quorum)
    |> case do
      remaining_quorum when remaining_quorum > 0 ->
        trace(inspect(self()), "Accept failed, quorum remaining: #{remaining_quorum}")
        {:error, :accept_failed}

      _ ->
        trace(
          inspect(self()),
          "Accept succeeded for key: #{inspect(key)}, with ballot number: #{ballot_number}, new value: #{
            inspect(value)
          }"
        )

        {:ok, value}
    end
  end

  defp collect_accept_responses(responses, quorum_left) do
    Enum.reduce_while(responses, quorum_left, fn
      {:ok, {_, :confirm}}, 1 ->
        {:halt, 0}

      {:ok, {_, :confirm}}, quorum_left ->
        {:cont, quorum_left - 1}

      {:ok, {_, :reject}}, quorum_left ->
        {:cont, quorum_left}
    end)
  end
end
