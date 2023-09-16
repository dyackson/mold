defmodule Mold.Any do
  alias Mold.Common
  alias __MODULE__, as: Any 

  defstruct [
    :also,
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
           :ok <- Common.apply_also(any, val) do
        :ok
      else
        :ok -> :ok
        :error -> {:error, any.error_message}
      end
    end

    defp add_error_message(%Any{error_message: error_message} = any) do
      case error_message do
        nil -> Map.put(any, :error_message, "must be something")
        _ -> any
      end
    end
  end
end
