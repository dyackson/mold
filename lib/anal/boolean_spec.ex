defmodule Anal.BoolSpec do
  alias __MODULE__, as: Spec
  alias Anal.Common

  defstruct [:error_message, :also, nil_ok?: false, __prepped__: false]

  defimpl Anal do
    def prep!(%Spec{} = spec) do
      spec
      |> Common.prep!()
      |> add_error_message()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Spec{} = spec, val) do
      spec = Common.check_prepped!(spec)

      with :not_nil <- Common.exam_nil(spec, val),
           :ok <- local_exam(spec, val),
           :ok <- Common.apply_also(spec, val) do
        :ok
      else
        :ok -> :ok
        :error -> {:error, spec.error_message}
      end
    end

    def add_error_message(%Spec{error_message: nil} = spec) do
      start = if spec.nil_ok?, do: "if not nil, ", else: ""
      Map.put(spec, :error_message, start <> "must be a boolean")
    end

    def add_error_message(%Spec{} = spec), do: spec

    def local_exam(%Spec{}, val) do
      if is_boolean(val), do: :ok, else: :error
    end
  end
end
