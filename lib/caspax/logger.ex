defmodule Caspax.Logger do
  defmacro __using__(_args) do
    quote do
      require Logger
      import unquote(__MODULE__)
    end
  end

  defmacro trace(name, message) do
    module_disp = inspect(__CALLER__.module)

    if Application.get_env(:caspax, :trace) do
      quote bind_quoted: [
              module_disp: module_disp,
              name: name,
              message: message
            ] do
        Logger.debug(["[", module_disp, "] [", name, "] ", message])
      end
    else
      quote do
      end
    end
  end
end
