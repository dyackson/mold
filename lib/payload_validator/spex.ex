defmodule PayloadValidator.Spex do
  @base_fields [nullable: false, and: nil]

  defmacro __using__(opts \\ []) do
    fields = Keyword.get(opts, :fields, [])
    fields = fields ++ @base_fields

    quote do
      defstruct unquote(fields)

      def new(opts \\ []) do
        with {:ok, spec} <- PayloadValidator.Spex.create_spec(__MODULE__, opts),
             {:ok, spec} <- PayloadValidator.Spex.validate_nullable(spec) do
          case PayloadValidator.SpexProtocol.validate_spec(spec) do
            {:error, reason} -> raise PayloadValidator.SpecError.new(reason)
            :ok -> spec
            %__MODULE__{} = transformed_spec -> transformed_spec
          end
        end
      end
    end
  end

  def validate_nullable(%{nullable: val}) when not is_boolean(val),
    do: {:error, ":nullable must be a boolean, got #{val}"}

  def validate_nullable(spec), do: {:ok, spec}

  def create_spec(module, opts) do
    try do
      {:ok, struct!(module, opts)}
    rescue
      e in KeyError -> {:error, "#{e.key} is not a field"}
    end
  end

  def get_name(module) do
    ["Elixir" | split_module_name] = module |> to_string() |> String.split(".")
    Enum.join(split_module_name, ".")
  end

  # TODO: maybe have an intermediate public function that checks that the spec is a spec
  # However, we want to avoid double checking all the specs in maps
  def validate(nil, %{nullable: true}), do: :ok
  def validate(nil, %{nullable: false}), do: {:error, "cannot be nil"}

  def validate(val, %{and: and_fn} = spec) do
    # first conform according to the module, then test the value agaist the :and function only if successful
    # delete the and so the implementer can't override the and behavior
    with :ok <- PayloadValidator.SpexProtocol.validate_val(spec, val) do
      apply_and_fn(and_fn, val)
    end
  end

  def apply_and_fn(fun, val) when is_function(fun) do
    case fun.(val) do
      :ok -> :ok
      true -> :ok
      false -> {:error, "invalid"}
      msg when is_binary(msg) -> {:error, msg}
      {:error, msg} when is_binary(msg) -> {:error, msg}
    end
  end

  def apply_and_fn(_fun, _val), do: :ok
end

defprotocol PayloadValidator.SpexProtocol do
  @fallback_to_any true
  def validate_spec(spec)
  def validate_val(spec, value)
end

defimpl PayloadValidator.SpexProtocol, for: Any do
  def validate_spec(_spec), do: :ok
  def validate_val(_spec, _val), do: :ok
end

defmodule PayloadValidator.Spex.String do
  use PayloadValidator.Spex, fields: [:regex]
end

defimpl PayloadValidator.SpexProtocol, for: PayloadValidator.Spex.String do
  def validate_spec(%{regex: regex}) do
    case regex do
      nil -> :ok
      %Regex{} -> :ok
      _ -> {:error, ":regex must be a Regex"}
    end
  end

  def validate_val(_spec, val) when not is_binary(val), do: {:error, "must be a string"}

  def validate_val(%{regex: regex}, val) when not is_nil(regex) do
    if Regex.match?(regex, val) do
      :ok
    else
      {:error, "must match regex: #{Regex.source(regex)}"}
    end
  end

  def validate_val(_spec, _val), do: :ok
end
