defmodule Anal.Spec do
  @base_fields [:also, :__error_message__, :get_error_message, can_be_nil: false]

  defmacro __using__(opts \\ []) do
    user_fields = Keyword.get(opts, :fields, [])
    fields = user_fields ++ @base_fields

    required_fields =
      user_fields
      |> Enum.filter(&match?({_, :required}, &1))
      |> Enum.map(fn {field, _} -> field end)

    quote do
      @enforce_keys unquote(required_fields)
      defstruct unquote(fields)
      alias Anal.Spec

      def new(opts \\ []) do
        spec = struct!(__MODULE__, opts)
        Spec.validate_base_fields!(spec)

        case Anal.SpecProtocol.validate_spec(spec) do
          :ok -> spec
          # this gives the implementation a chance to transform the spec
          {:ok, %__MODULE__{} = spec} -> spec
          {:error, reason} -> raise Anal.SpecError.new(reason)
        end
      end
    end
  end

  def validate_base_fields!(%{can_be_nil: val}) when not is_boolean(val),
    do: raise(Anal.SpecError.new(":can_be_nil must be a boolean, got #{inspect(val)}"))

  def validate_base_fields!(%{also: also})
      when not is_nil(also) and not is_function(also, 1),
      do: raise(Anal.SpecError.new(":also must be a 1-arity function, got #{inspect(also)}"))

  def validate_base_fields!(_spec), do: :ok

  def validate(val, spec) do
    Anal.SpecProtocol.impl_for!(spec)

    case {val, spec} do
      {nil, %{can_be_nil: true}} ->
        :ok

      {nil, %{can_be_nil: false}} ->
        {:error, "cannot be nil"}

      {_, _} ->
        with :ok <- Anal.SpecProtocol.validate_val(spec, val) do
          apply_also(spec.also, val)
        end
    end
  end

  def apply_also(fun, val) when is_function(fun) do
    case fun.(val) do
      :ok -> :ok
      {:error, msg} when is_binary(msg) -> {:error, msg}
    end
  end

  def apply_also(_fun, _val), do: :ok

  def recurse(key_in_parent, value, spec) when is_map(spec) do
    case validate(value, spec) do
      :ok ->
        :ok

      {:error, error_msg} when is_binary(error_msg) ->
        {[key_in_parent], error_msg}

      {:error, error_map} when is_map(error_map) ->
        Enum.map(error_map, fn {path, error_msg} when is_list(path) and is_binary(error_msg) ->
          {[key_in_parent | path], error_msg}
        end)
    end
  end

  def is_spec?(val), do: Anal.SpecProtocol.impl_for(val) != nil
end
