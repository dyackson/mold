defmodule PayloadValidator.StringSpec do
  use PayloadValidator.Spec,
    conform_fn_name: :string,
    fields: [:enum_vals, :case_insensative, :regex]

  def check_spec(%__MODULE__{enum_vals: enum_vals, regex: regex})
      when not is_nil(regex) and not is_nil(enum_vals),
      do: {:error, ":enum_vals and :regex are not allowed together"}

  def check_spec(%__MODULE__{enum_vals: enum_vals, case_insensative: case_insensative})
      when not is_nil(case_insensative) and is_nil(enum_vals),
      do: {:error, ":case_insensative is only allowed with enum_vals"}

  def check_spec(%__MODULE__{case_insensative: case_insensative})
      when not is_boolean(case_insensative) and not is_nil(case_insensative),
      do: {:error, ":case_insensative must be a boolean"}

  def check_spec(%__MODULE__{enum_vals: enum_vals})
      when not is_list(enum_vals) and not is_nil(enum_vals),
      do: {:error, ":enum_vals must be a list"}

  def check_spec(%__MODULE__{enum_vals: []}), do: {:error, ":enum_vals cannot be empty"}

  def check_spec(%__MODULE__{enum_vals: enum_vals}) when is_list(enum_vals) do
    if Enum.all?(enum_vals, &is_binary(&1)),
      do: :ok,
      else: {:error, ":enum_vals can only contain strings"}
  end

  def check_spec(%__MODULE__{regex: regex}) do
    case regex do
      nil -> :ok
      %Regex{} -> :ok
      _ -> {:error, ":regex must be a Regex"}
    end
  end

  def conform(val, %__MODULE__{}) when not is_binary(val), do: {:error, "must be a string"}

  def conform(val, %__MODULE__{regex: regex}) when not is_nil(regex) do
    if Regex.match?(regex, val) do
      :ok
    else
      {:error, "must match regex: #{Regex.source(regex)}"}
    end
  end

  def conform(val, %__MODULE__{enum_vals: enum_vals, case_insensative: true})
      when is_list(enum_vals) do
    val = String.downcase(val)
    enum_vals = Enum.map(enum_vals, &String.downcase/1)

    if val in enum_vals,
      do: :ok,
      else: {:error, "must be one of: #{Enum.join(enum_vals, ", ")} (case insensative)"}
  end

  def conform(val, %__MODULE__{enum_vals: enum_vals}) when is_list(enum_vals) do
    if val in enum_vals,
      do: :ok,
      else: {:error, "must be one of: #{Enum.join(enum_vals, ", ")} (case sensative)"}
  end

  def conform(_, %__MODULE__{}), do: :ok
end
