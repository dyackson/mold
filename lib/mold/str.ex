defmodule Mold.Str do
  alias Mold.Common
  alias Mold.Error
  alias __MODULE__, as: Str

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

    def prep!(%Str{} = mold) do
      mold
      |> Common.prep!()
      |> local_prep!()
      |> add_error_message()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Str{} = mold, val) do
      mold = Common.check_prepped!(mold)

      with :not_nil <- Common.exam_nil(mold, val),
           :ok <- local_exam(mold, val),
           :ok <- Common.apply_also(mold, val) do
        :ok
      else
        :ok -> :ok
        :error -> {:error, mold.error_message}
      end
    end

    defp local_prep!(%Str{regex: regex, one_of: one_of})
         when not is_nil(regex) and not is_nil(one_of),
         do: raise(Error.new("cannot use both :regex and :one_of"))

    defp local_prep!(%Str{regex: regex, one_of_ci: one_of_ci})
         when not is_nil(regex) and not is_nil(one_of_ci),
         do: raise(Error.new("cannot use both :regex and :one_of_ci"))

    defp local_prep!(%Str{one_of: one_of, one_of_ci: one_of_ci})
         when not is_nil(one_of) and not is_nil(one_of_ci),
         do: raise(Error.new("cannot use both :one_of and :one_of_ci"))

    defp local_prep!(%Str{} = mold)
         when (not is_nil(mold.one_of) or not is_nil(mold.one_of_ci) or not is_nil(mold.regex)) and
                (not is_nil(mold.min_length) or not is_nil(mold.max_length)) do
      field1 = Enum.find([:one_of, :one_of_ci, :regex], &(Map.get(mold, &1) != nil))
      field2 = Enum.find([:min_length, :max_length], &(Map.get(mold, &1) != nil))

      raise Error.new("cannot use both #{inspect(field1)} and #{inspect(field2)}")
    end

    defp local_prep!(%Str{one_of: one_of}) when not (is_list(one_of) or is_nil(one_of)),
      do: raise(Error.new(":one_of #{@non_empty_list_msg}"))

    defp local_prep!(%Str{one_of_ci: one_of_ci})
         when not (is_list(one_of_ci) or is_nil(one_of_ci)),
         do: raise(Error.new(":one_of_ci #{@non_empty_list_msg}"))

    defp local_prep!(%Str{one_of: []}),
      do: raise(Error.new(":one_of #{@non_empty_list_msg}"))

    defp local_prep!(%Str{one_of_ci: []}),
      do: raise(Error.new(":one_of_ci #{@non_empty_list_msg}"))

    ## Now at most one non-null field in [:regex, :one_of, :one_of_ci] will be present

    defp local_prep!(%Str{one_of: one_of} = mold) when is_list(one_of) do
      if Enum.all?(one_of, &is_binary/1) do
        mold
      else
        raise Error.new(":one_of #{@non_empty_list_msg}")
      end
    end

    defp local_prep!(%Str{one_of_ci: one_of_ci} = mold) when is_list(one_of_ci) do
      if Enum.all?(one_of_ci, &is_binary/1) do
        downcased = Enum.map(one_of_ci, &String.downcase/1)
        Map.put(mold, :one_of_ci, downcased)
      else
        raise Error.new(":one_of_ci #{@non_empty_list_msg}")
      end
    end

    defp local_prep!(%Str{regex: regex} = mold) when not is_nil(regex) do
      case regex do
        %Regex{} -> mold
        _ -> raise Error.new(":regex must be a Regex")
      end
    end

    defp local_prep!(%Str{min_length: min})
         when not (is_nil(min) or (is_integer(min) and min > 0)) do
      raise Error.new(":min_length must be a positive integer")
    end

    defp local_prep!(%Str{max_length: max})
         when not (is_nil(max) or (is_integer(max) and max > 0)) do
      raise Error.new(":max_length must be a positive integer")
    end

    defp local_prep!(%Str{min_length: min, max_length: max})
         when is_integer(min) and is_integer(max) and min > max do
      raise Error.new(":max_length must be greater than or equal to :min_length")
    end

    defp local_prep!(%Str{} = mold), do: mold

    defp add_error_message(%Str{error_message: nil} = mold) do
      # a valid mold will use at most one of regex, one_of, one_of_ci, and length restrictions
      error_message =
        case mold do
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

      Map.put(mold, :error_message, error_message)
    end

    defp add_error_message(%Str{} = mold), do: mold

    def local_exam(%Str{}, val) when not is_binary(val), do: :error

    def local_exam(%Str{regex: regex}, val) when regex != nil do
      if Regex.match?(regex, val), do: :ok, else: :error
    end

    def local_exam(%Str{one_of: one_of}, val) when one_of != nil do
      if val in one_of, do: :ok, else: :error
    end

    def local_exam(%Str{one_of_ci: already_downcased}, val) when already_downcased != nil do
      if String.downcase(val) in already_downcased, do: :ok, else: :error
    end

    def local_exam(%Str{min_length: min, max_length: max}, val)
        when is_integer(min) or is_integer(max) do
      len = String.length(val)

      cond do
        is_integer(min) and len < min -> :error
        is_integer(max) and len > max -> :error
        true -> :ok
      end
    end

    def local_exam(%Str{}, _val), do: :ok
  end
end
