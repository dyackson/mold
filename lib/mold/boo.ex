defmodule Mold.Boo do
  alias __MODULE__, as: Boo
  alias Mold.Common

  defstruct [:error_message, :but, nil_ok?: false, __prepped__: false]

  defimpl Mold.Protocol do
    def prep!(%Boo{} = mold) do
      mold
      |> Common.prep!()
      |> add_error_message()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Boo{} = mold, val) do
      mold = Common.check_prepped!(mold)

      with :not_nil <- Common.exam_nil(mold, val),
           :ok <- local_exam(mold, val),
           :ok <- Common.apply_but(mold, val) do
        :ok
      else
        :ok -> :ok
        :error -> {:error, mold.error_message}
      end
    end

    def add_error_message(%Boo{error_message: nil} = mold) do
      start = if mold.nil_ok?, do: "if not nil, ", else: ""
      Map.put(mold, :error_message, start <> "must be a boolean")
    end

    def add_error_message(%Boo{} = mold), do: mold

    def local_exam(%Boo{}, val) do
      if is_boolean(val), do: :ok, else: :error
    end
  end
end
