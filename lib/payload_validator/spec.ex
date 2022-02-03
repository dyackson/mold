defmodule PayloadValidator.Spec do
  alias PayloadValidator.SpecError
  alias PayloadValidator.SpecBehavior

  @base_fields [required: false, nullable: false]

  defmacro __using__(opts \\ []) do
    conform_fn_name = Keyword.get(opts, :conform_fn_name, :new)
    fields = Keyword.get(opts, :fields, [])
    fields = fields ++ @base_fields

    quote do
      defstruct unquote(fields)

      @behaviour SpecBehavior

      def unquote(conform_fn_name)(opts \\ []),
        do: PayloadValidator.Spec.create_spec(__MODULE__, unquote(conform_fn_name), opts)

      def conform(nil, %__MODULE__{nullable: true}), do: :ok
      def conform(nil, %__MODULE__{nullable: false}), do: {:error, "cannot be nil"}
    end
  end

  def check_spec(%{required: required}) when not is_boolean(required),
    do: {:error, "required must be a boolean"}

  def check_spec(%{nullable: nullable}) when not is_boolean(nullable),
    do: {:error, "nullable must be a boolean"}

  def check_spec(%{}), do: :ok

  def is_spec?(val) do
    is_map(val) and Map.has_key?(val, :__struct__) and
      Map.has_key?(val, :nullable) and
      Map.has_key?(val, :required) and
      Kernel.function_exported?(val.__struct__, :check_spec, 1) and
      Kernel.function_exported?(val.__struct__, :conform, 2)
  end

  def create_spec(spec_module, fun_name, opts) do
    module_name = get_name(spec_module)
    fun_id = "#{module_name}.#{fun_name}/1"

    unless Keyword.keyword?(opts),
      do: raise(SpecError.new("for #{fun_id}, opts must be a keyword list"))

    spec =
      try do
        struct!(spec_module, opts)
      rescue
        e in KeyError -> raise(SpecError.new("for #{fun_id}, #{e.key} is not an option"))
      end

    with :ok <- check_spec(spec),
         {:ok, spec} <- apply_module_check_spec(spec_module, spec) do
      spec
    else
      {:error, msg} -> raise SpecError.new("for #{fun_id}, #{msg}")
    end
  end

  defp apply_module_check_spec(spec_module, spec) do
    case apply(spec_module, :check_spec, [spec]) do
      :ok -> {:ok, spec}
      # the module transformed the spec
      {:ok, spec} -> {:ok, spec}
      {:error, msg} -> {:error, msg}
    end
  end

  defp get_name(module) do
    ["Elixir" | split_module_name] = module |> to_string() |> String.split(".")
    Enum.join(split_module_name, ".")
  end

  def recurse(key, value, spec) when is_map(spec) do
    case spec.__struct__.conform(value, spec) do
      :ok ->
        :ok

      {:error, error_msg} when is_binary(error_msg) ->
        {[key], error_msg}

      {:error, error_map} when is_map(error_map) ->
        Enum.map(error_map, fn {path, error_msg} when is_list(path) and is_binary(error_msg) ->
          {[key | path], error_msg}
        end)
    end
  end
end
