defmodule Anal.StringSpec do
  use Anal.Spec, fields: [:regex, :one_of, :one_of_ci]
end

defimpl Anal.SpecProtocol, for: Anal.StringSpec do
  @non_empty_list_msg "must be a non-empty list of strings"

  def validate_spec(%{regex: regex, one_of: one_of})
      when not is_nil(regex) and not is_nil(one_of),
      do: {:error, "cannot use both :regex and :one_of"}

  def validate_spec(%{regex: regex, one_of_ci: one_of_ci})
      when not is_nil(regex) and not is_nil(one_of_ci),
      do: {:error, "cannot use both :regex and :one_of_ci"}

  def validate_spec(%{one_of: one_of, one_of_ci: one_of_ci})
      when not is_nil(one_of) and not is_nil(one_of_ci),
      do: {:error, "cannot use both :one_of and :one_of_ci"}

  def validate_spec(%{one_of: one_of}) when not (is_list(one_of) or is_nil(one_of)),
    do: {:error, ":one_of #{@non_empty_list_msg}"}

  def validate_spec(%{one_of_ci: one_of_ci}) when not (is_list(one_of_ci) or is_nil(one_of_ci)),
    do: {:error, ":one_of_ci #{@non_empty_list_msg}"}

  def validate_spec(%{one_of: []}), do: {:error, ":one_of #{@non_empty_list_msg}"}

  def validate_spec(%{one_of_ci: []}), do: {:error, ":one_of_ci #{@non_empty_list_msg}"}

  ## Now at most non-null field is will be present

  def validate_spec(%{one_of: one_of}) when is_list(one_of) do
    if Enum.all?(one_of, &is_binary/1) do
      :ok
    else
      {:error, ":one_of #{@non_empty_list_msg}"}
    end
  end

  def validate_spec(%{one_of_ci: one_of_ci} = spec) when is_list(one_of_ci) do
    if Enum.all?(one_of_ci, &is_binary/1) do
      downcased = Enum.map(one_of_ci, &String.downcase/1)
      {:ok, Map.put(spec, :one_of_ci, downcased)}
    else
      {:error, ":one_of_ci #{@non_empty_list_msg}"}
    end
  end

  def validate_spec(%{regex: regex}) when not is_nil(regex) do
    case regex do
      %Regex{} -> :ok
      _ -> {:error, ":regex must be a Regex"}
    end
  end

  def validate_spec(_), do: :ok

  def validate_val(_spec, val) when not is_binary(val), do: {:error, "must be a string"}

  def validate_val(%{regex: regex}, val) when not is_nil(regex) do
    if Regex.match?(regex, val) do
      :ok
    else
      {:error, "must match regex: #{Regex.source(regex)}"}
    end
  end

  def validate_val(%{one_of: one_of}, val) when is_list(one_of) do
    if val in one_of do
      :ok
    else
      {:error, "must be a case-sensative match for one of: #{Enum.join(one_of, ", ")}"}
    end
  end

  def validate_val(%{one_of_ci: already_downcased}, val) when is_list(already_downcased) do
    if String.downcase(val) in already_downcased do
      :ok
    else
      {:error,
       "must be a case-insensative match for one of: #{Enum.join(already_downcased, ", ")}"}
    end
  end

  def validate_val(_spec, _val), do: :ok
end
