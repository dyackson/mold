defmodule Dammit.Spec.List do
  use Dammit.Spec,
    fields: [:min_len, :max_len, of: :required]
end

defimpl Dammit.ValidateSpec, for: Dammit.Spec.List do
  def validate_spec(%{min_len: min_len})
      when not is_nil(min_len) and not (is_integer(min_len) and min_len >= 0),
      do: {:error, ":min_len must be a non-negative integer"}

  def validate_spec(%{max_len: max_len})
      when not is_nil(max_len) and not (is_integer(max_len) and max_len >= 0),
      do: {:error, ":max_len must be a non-negative integer"}

  def validate_spec(%{min_len: min_len, max_len: max_len})
      when is_integer(min_len) and is_integer(max_len) and min_len > max_len,
      do: {:error, ":min_len cannot be greater than :max_len"}

  def validate_spec(%{of: of}) do
    if Dammit.Spec.is_spec?(of),
      do: :ok,
      else: {:error, ":of must be a spec"}
  end

  def validate_spec(_spec), do: :ok
end

defimpl Dammit.ValidateVal, for: Dammit.Spec.List do
  def validate_val(%{} = _spec, val) when not is_list(val), do: {:error, "must be a list"}

  def validate_val(%{of: item_spec, min_len: min_len, max_len: max_len} = _spec, list) do
    with :ok <- validate_min_len(list, min_len),
         :ok <- validate_max_len(list, max_len) do
      item_errors =
        list
        |> Enum.with_index()
        |> Enum.map(fn {item, index} ->
          Dammit.Spec.recurse(index, item, item_spec)
        end)
        |> Enum.filter(&(&1 != :ok))
        |> Map.new()

      if item_errors == %{} do
        :ok
      else
        {:error, item_errors}
      end
    end
  end

  defp validate_min_len(_list, nil), do: :ok

  defp validate_min_len(list, min) do
    if length(list) < min do
      {:error, "length must be at least #{min}"}
    else
      :ok
    end
  end

  defp validate_max_len(_list, nil), do: :ok

  defp validate_max_len(list, max) do
    if length(list) > max do
      {:error, "length cannot exceed #{max}"}
    else
      :ok
    end
  end
end
