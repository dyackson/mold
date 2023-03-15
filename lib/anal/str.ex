defmodule Anal.Str do
  alias Anal.Common
  alias Anal.SpecError
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

  defimpl Anal do
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

    defp local_prep!(%Spec{} = spec), do: spec

    defp add_error_message(%Spec{error_message: nil} = spec) do
      message_start = "must be a string"

      # a valid spec will use at most one of regex, one_of, and one_of_ci
      message_end =
        case spec do
          %{regex: regex} when regex != nil ->
            " that matches regex #{Regex.source(regex)}"

          %{one_of: one_of} when one_of != nil ->
            " that is a case-sensative match for one of: #{Enum.join(one_of, ", ")}"

          %{one_of_ci: one_of_ci} when one_of_ci != nil ->
            " that is a case-insensative match for one of: #{Enum.join(one_of_ci, ", ")}"

          _ ->
            ""
        end

      Map.put(spec, :error_message, message_start ++ message_end)
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

    def local_exam(%Spec{}, _val), do: :ok
  end
end
