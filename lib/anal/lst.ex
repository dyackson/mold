# defmodule Anal.Lst do
defmodule Anal.Lst do
  alias Anal.Common
  alias Anal.SpecError
  alias __MODULE__, as: Spec

  defstruct [
    :also,
    :error_message,
    :of,
    :min_length,
    :max_length,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Anal do
    def prep!(%Spec{} = spec) do
      spec
      |> Common.prep!()
      |> local_prep!()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Spec{} = spec, val) do
      spec = Common.check_prepped!(spec)

      case {spec.nil_ok?, val} do
        {true, nil} ->
          :ok

        {false, nil} ->
          {:error, spec.error_message}

        _ ->
          # check the non-nil value with the spec
          with :ok <- local_exam(spec, val),
               :ok <- Common.apply_also(spec, val) do
            :ok
          else
            :error -> {:error, spec.error_message}
            {:error, %{} = _nested_error_map} = it -> it
          end
      end
    end

    defp local_prep!(%Spec{} = spec) do
      length_error_msg =
        case spec do
          %{min_length: l} when not (is_nil(l) or (is_integer(l) and l >= 0)) ->
            ":min_length must be a non-negative integer"

          %{max_length: l} when not (is_nil(l) or (is_integer(l) and l > 0)) ->
            ":max_length must be a positive integer"

          %{min_length: min, max_length: max}
          when is_integer(min) and is_integer(max) and min > max ->
            ":min_length must be less than or equal to :max_length"

          _ ->
            nil
        end

      if is_binary(length_error_msg), do: raise(SpecError.new(length_error_msg))

      if not is_spec?(spec.of),
        do: raise(SpecError.new(":of is required and must implement the Anal protocol"))

      spec = Map.put(spec, :of, Anal.prep!(spec.of))
      # add the error message to the spec
      if is_binary(spec.error_message) do
        # user-supplied error message exists, use it, nothing to do
        spec
      else
        error_message =
          case {spec.min_length, spec.max_length} do
            {nil, nil} -> "must be a list"
            {min, nil} -> "must be a list with at least #{min} elements"
            {nil, max} -> "must be a list with at most #{max} elements"
            {min, max} -> "must be a list with at least #{min} and at most #{max} elements"
          end

        Map.put(spec, :error_message, error_message)
      end
    end

    defp local_exam(%Spec{}, val) when not is_list(val), do: :error

    defp local_exam(%Spec{min_length: min_length, max_length: max_length} = spec, val) do
      length = if is_integer(min_length) or is_integer(max_length), do: length(val)

      cond do
        is_integer(min_length) && length < min_length ->
          :error

        is_integer(max_length) && length > max_length ->
          :error

        true ->
          item_errors_map =
            val
            |> Enum.with_index()
            |> Enum.reduce(%{}, fn {item, index}, acc ->
              case Anal.exam(spec.of, item) do
                :ok -> acc
                {:error, e} when is_binary(e) or is_map(e) -> Map.put(acc, index, e)
              end
            end)

          if item_errors_map == %{}, do: :ok, else: {:error, item_errors_map}
      end
    end

    def is_spec?(val), do: Anal.impl_for(val) != nil
  end
end
