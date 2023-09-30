defmodule Mold.Int do
  alias Mold.Common
  alias Mold.Error
  alias __MODULE__, as: Int

  defstruct [
    :gt,
    :lt,
    :gte,
    :lte,
    :but,
    :error_message,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Mold.Protocol do
    def prep!(%Int{} = mold) do
      mold = Common.prep!(mold)

      bad_bound =
        case mold do
          %{lt: lt} when not (lt == nil or is_integer(lt)) ->
            :lt

          %{lte: lte} when not (lte == nil or is_integer(lte)) ->
            :lte

          %{gt: gt} when not (gt == nil or is_integer(gt)) ->
            :gt

          %{gte: gte} when not (gte == nil or is_integer(gte)) ->
            :gte

          _ ->
            nil
        end

      if bad_bound, do: raise(Error.new("#{inspect(bad_bound)} must be an integer"))

      if is_integer(mold.gt) and is_integer(mold.gte),
        do: raise(Error.new("cannot use both :gt and :gte"))

      if is_integer(mold.lt) and is_integer(mold.lte),
        do: raise(Error.new("cannot use both :lt and :lte"))

      impossible_bounds =
        case mold do
          %{gt: gt, lt: lt} when is_integer(gt) and is_integer(lt) and gt >= lt ->
            {:gt, :lt}

          %{gt: gt, lte: lte} when is_integer(gt) and is_integer(lte) and gt >= lte ->
            {:gt, :lte}

          %{gte: gte, lt: lt} when is_integer(gte) and is_integer(lt) and gte >= lt ->
            {:gte, :lt}

          %{gte: gte, lte: lte} when is_integer(gte) and is_integer(lte) and gte >= lte ->
            {:gte, :lte}

          _ ->
            nil
        end

      case impossible_bounds do
        {lower, upper} ->
          raise Error.new("#{inspect(lower)} must be less than #{inspect(upper)}")

        nil ->
          nil
      end

      mold
      |> add_error_message()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Int{} = mold, val) do
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
          end
      end
    end

    defp local_exam(%Int{} = mold, val) do
      with true <- is_integer(val),
           true <- mold.lt == nil or val < mold.lt,
           true <- mold.lte == nil or val <= mold.lte,
           true <- mold.gt == nil or val > mold.gt,
           true <- mold.gte == nil or val >= mold.gte do
        :ok
      else
        _ -> :error
      end
    end

    def add_error_message(%Int{error_message: nil} = mold) do
      details =
        Enum.reduce(
          [
            gt: "greater than",
            gte: "greater than or equal to",
            lt: "less than",
            lte: "less than or equal to"
          ],
          [],
          fn {bound, desc}, details ->
            case Map.get(mold, bound) do
              nil -> details
              int when is_integer(int) -> ["#{desc} #{int}" | details]
            end
          end
        )

      # add the details in the opposite order that they'll be displayed
      # so we can append to the front of the list and reverse at the end
      details =
        case Enum.reverse(details) do
          [] -> ""
          [d1] -> " " <> d1
          [d1, d2] -> " " <> d1 <> " and " <> d2
        end

      preamble = if mold.nil_ok?, do: "if not nil, ", else: ""

      Map.put(
        mold,
        :error_message,
        preamble <> "must be an integer" <> details
      )
    end

    def add_error_message(%Int{} = mold), do: mold
  end
end
