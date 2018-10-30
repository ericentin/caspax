defmodule BallotNumberTest do
  use ExUnit.Case
  alias Caspax.BallotNumber
  @moduletag BallotNumber

  setup_all do
    Caspax.BallotNumber = BallotNumber.init()
    :ok
  end

  test "multi init works" do
    assert Caspax.BallotNumber == BallotNumber.init()
  end

  test "reqular sequence works" do
    assert 0 == BallotNumber.get_next()
    assert 1 == BallotNumber.get_next()
    assert 2 == BallotNumber.get_next()
    assert 3 == BallotNumber.get_next()
    assert 4 == BallotNumber.get_next()
    assert 5 == BallotNumber.get_next()
  end

  test "fast forward works" do
    assert 6 == BallotNumber.get_next()
    assert 100 == BallotNumber.fast_forward(100)
    assert 101 == BallotNumber.get_next()
  end

  test "fast forward does not go backwards" do
    assert 101 == BallotNumber.fast_forward(0)
    assert 102 == BallotNumber.get_next()
  end
end
