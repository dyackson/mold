# defmodule Mold.Lst do
defmodule Mold.Lst do
  alias Mold.Common
  alias Mold.Error
  alias __MODULE__, as: Lst

  defstruct [
    :but,
    :error_message,
    :of,
    :min,
    :max,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Mold.Protocol do
    def prep!(%Lst{} = mold) do
      mold
      |> Common.prep!()
      |> local_prep!()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Lst{} = mold, val) do
      mold = Common.check_prepped!(mold)

      case {mold.nil_ok?, val} do
        {true, nil} ->
          :ok

        {false, nil} ->
          {:error, mold.error_message}

        _ ->
          # check the non-nil value with the mold
          with :ok <- local_exam(mold, val),
               :ok <- Common.apply_but(mold, val) do
            :ok
          else
            :error -> {:error, mold.error_message}
            {:error, %{} = _nested_error_map} = it -> it
          end
      end
    end

    defp local_prep!(%Lst{} = mold) do
      length_error_msg =
        case mold do
          %{min: l} when not (is_nil(l) or (is_integer(l) and l >= 0)) ->
            ":min must be a non-negative integer"

          %{max: l} when not (is_nil(l) or (is_integer(l) and l > 0)) ->
            ":max must be a positive integer"

          %{min: min, max: max}
          when is_integer(min) and is_integer(max) and min > max ->
            ":min must be less than or equal to :max"

          _ ->
            nil
        end

      if is_binary(length_error_msg), do: raise(Error.new(length_error_msg))

      if not is_mold?(mold.of),
        do: raise(Error.new(":of is required and must implement the Mold protocol"))

      mold = Map.put(mold, :of, Mold.prep!(mold.of))
      # add the error message to the mold
      if is_binary(mold.error_message) do
        # user-supplied error message exists, use it, nothing to do
        mold
      else
        error_message =
          case {mold.min, mold.max} do
            {nil, nil} ->
              "must be a list in which each element " <> mold.of.error_message

            {min, nil} ->
              "must be a list with at least #{min} elements, each of which " <>
                mold.of.error_message

            {nil, max} ->
              "must be a list with at most #{max} elements, each of which " <>
                mold.of.error_message

            {min, max} ->
              "must be a list with at least #{min} and at most #{max} elements, each of which " <>
                mold.of.error_message
          end

        error_message =
          if mold.nil_ok? do
            "if not nil, " <> error_message
          else
            error_message
          end

        Map.put(mold, :error_message, error_message)
      end
    end

    defp local_exam(%Lst{}, val) when not is_list(val), do: :error

    defp local_exam(%Lst{min: min, max: max} = mold, val) do
      length = if is_integer(min) or is_integer(max), do: length(val)

      cond do
        is_integer(min) && length < min ->
          :error

        is_integer(max) && length > max ->
          :error

        true ->
          item_errors_map =
            val
            |> Enum.with_index()
            |> Enum.reduce(%{}, fn {item, index}, acc ->
              case Mold.exam(mold.of, item) do
                :ok -> acc
                {:error, e} when is_binary(e) or is_map(e) -> Map.put(acc, index, e)
              end
            end)

          if item_errors_map == %{}, do: :ok, else: {:error, item_errors_map}
      end
    end

    def is_mold?(val), do: Mold.Protocol.impl_for(val) != nil
  end
end
