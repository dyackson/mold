defmodule Mold.Any do
  alias Mold.Common
  alias __MODULE__, as: Any

  defstruct [
    :but,
    :error_message,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Mold do
    def prep!(%Any{} = any) do
      any
      |> Common.prep!()
      |> add_error_message()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Any{} = any, val) do
      any = Common.check_prepped!(any)

      with :not_nil <- Common.exam_nil(any, val),
           :ok <- Common.apply_but(any, val) do
        :ok
      else
        :ok -> :ok
        :error -> {:error, any.error_message}
      end
    end

    defp add_error_message(%Any{error_message: error_message, nil_ok?: nil_ok?} = any) do
      case {error_message, nil_ok?} do
        # this first case can only happen if a user supplies :but, but not :error_message
        {nil, true} -> Map.put(any, :error_message, "invalid")
        {nil, false} -> Map.put(any, :error_message, "must not be nil")
        _ -> any
      end
    end
  end
end
