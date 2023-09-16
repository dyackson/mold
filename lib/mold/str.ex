defmodule Mold.Str do
  alias Mold.Common
  alias Mold.SpecError
  alias __MODULE__, as: Spec

  defstruct [
    :regex,
    :one_of,
    :one_of_ci,
    :min_length,
    :max_length,
    :also,
    :error_message,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Mold do
    @non_empty_list_msg "must be a non-empty list of strings"

    def prep!(%Spec{} = spec) do
      spec
      |> Common.prep!()
      |> local_prep!()
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

    defp local_prep!(%Spec{regex: regex, one_of: one_of})
         when not is_nil(regex) and not is_nil(one_of),
         do: raise(SpecError.new("cannot use both :regex and :one_of"))

    defp local_prep!(%Spec{regex: regex, one_of_ci: one_of_ci})
         when not is_nil(regex) and not is_nil(one_of_ci),
         do: raise(SpecError.new("cannot use both :regex and :one_of_ci"))

    defp local_prep!(%Spec{one_of: one_of, one_of_ci: one_of_ci})
         when not is_nil(one_of) and not is_nil(one_of_ci),
         do: raise(SpecError.new("cannot use both :one_of and :one_of_ci"))

    defp local_prep!(%Spec{} = spec)
         when (not is_nil(spec.one_of) or not is_nil(spec.one_of_ci) or not is_nil(spec.regex)) and
                (not is_nil(spec.min_length) or not is_nil(spec.max_length)) do
      field1 = Enum.find([:one_of, :one_of_ci, :regex], &(Map.get(spec, &1) != nil))
      field2 = Enum.find([:min_length, :max_length], &(Map.get(spec, &1) != nil))

      raise SpecError.new("cannot use both #{inspect(field1)} and #{inspect(field2)}")
    end

    defp local_prep!(%Spec{one_of: one_of}) when not (is_list(one_of) or is_nil(one_of)),
      do: raise(SpecError.new(":one_of #{@non_empty_list_msg}"))

    defp local_prep!(%Spec{one_of_ci: one_of_ci})
         when not (is_list(one_of_ci) or is_nil(one_of_ci)),
         do: raise(SpecError.new(":one_of_ci #{@non_empty_list_msg}"))

    defp local_prep!(%Spec{one_of: []}),
      do: raise(SpecError.new(":one_of #{@non_empty_list_msg}"))

    defp local_prep!(%Spec{one_of_ci: []}),
      do: raise(SpecError.new(":one_of_ci #{@non_empty_list_msg}"))

    ## Now at most one non-null field in [:regex, :one_of, :one_of_ci] will be present

    defp local_prep!(%Spec{one_of: one_of} = spec) when is_list(one_of) do
      if Enum.all?(one_of, &is_binary/1) do
        spec
      else
        raise SpecError.new(":one_of #{@non_empty_list_msg}")
      end
    end

    defp local_prep!(%Spec{one_of_ci: one_of_ci} = spec) when is_list(one_of_ci) do
      if Enum.all?(one_of_ci, &is_binary/1) do
        downcased = Enum.map(one_of_ci, &String.downcase/1)
        Map.put(spec, :one_of_ci, downcased)
      else
        raise SpecError.new(":one_of_ci #{@non_empty_list_msg}")
      end
    end

    defp local_prep!(%Spec{regex: regex} = spec) when not is_nil(regex) do
      case regex do
        %Regex{} -> spec
        _ -> raise SpecError.new(":regex must be a Regex")
      end
    end

    defp local_prep!(%Spec{min_length: min})
         when not (is_nil(min) or (is_integer(min) and min > 0)) do
      raise SpecError.new(":min_length must be a positive integer")
    end

    defp local_prep!(%Spec{max_length: max})
         when not (is_nil(max) or (is_integer(max) and max > 0)) do
      raise SpecError.new(":max_length must be a positive integer")
    end

    defp local_prep!(%Spec{min_length: min, max_length: max})
         when is_integer(min) and is_integer(max) and min > max do
      raise SpecError.new(":max_length must be greater than or equal to :min_length")
    end

    defp local_prep!(%Spec{} = spec), do: spec

    defp add_error_message(%Spec{error_message: nil} = spec) do
      # a valid spec will use at most one of regex, one_of, one_of_ci, and length restrictions
      error_message =
        case spec do
          %{regex: regex} when regex != nil ->
            "must be a string matching the regex #{inspect(regex)}"

          %{one_of: one_of} when one_of != nil ->
            one_of = one_of |> Enum.map(&~s["#{&1}"]) |> Enum.join(", ")
            "must be one of these strings (with matching case): #{one_of}"

          %{one_of_ci: one_of_ci} when one_of_ci != nil ->
            one_of_ci = one_of_ci |> Enum.map(&~s["#{&1}"]) |> Enum.join(", ")
            "must be one of these strings (case doesn't have to match): #{one_of_ci}"

          %{min_length: min, max_length: nil} when is_integer(min) ->
            "must be a string with at least #{min} characters"

          %{min_length: nil, max_length: max} when is_integer(max) ->
            "must be a string with at most #{max} characters"

          %{min_length: min, max_length: max} when is_integer(min) and is_integer(max) ->
            "must be a string with at least #{min} and at most #{max} characters"

          _ ->
            "must be a string"
        end

      Map.put(spec, :error_message, error_message)
    end

    defp add_error_message(%Spec{} = spec), do: spec

    def local_exam(%Spec{}, val) when not is_binary(val), do: :error

    def local_exam(%Spec{regex: regex}, val) when regex != nil do
      if Regex.match?(regex, val), do: :ok, else: :error
    end

    def local_exam(%Spec{one_of: one_of}, val) when one_of != nil do
      if val in one_of, do: :ok, else: :error
    end

    def local_exam(%Spec{one_of_ci: already_downcased}, val) when already_downcased != nil do
      if String.downcase(val) in already_downcased, do: :ok, else: :error
    end

    def local_exam(%Spec{min_length: min, max_length: max}, val)
        when is_integer(min) or is_integer(max) do
      len = String.length(val)

      cond do
        is_integer(min) and len < min -> :error
        is_integer(max) and len > max -> :error
        true -> :ok
      end
    end

    def local_exam(%Spec{}, _val), do: :ok
  end
end
