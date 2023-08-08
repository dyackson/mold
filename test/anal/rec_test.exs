defmodule Anal.RecTest do
  alias Anal.SpecError
  alias Anal.Rec

  use ExUnit.Case

  describe "Anal.prep! a Rec raises a SpecError when" do
    test "nil_ok? not a boolean" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Anal.prep!(%Rec{nil_ok?: "yuh"})
      end)
    end

    test ":also is not an arity-1 function" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Anal.prep!(%Rec{also: &(&1 + &2)})
      end)
    end

    test ":exclusive? is not a boolean" do
      assert_raise(
        SpecError,
        ":exclusive? must be a boolean",
        fn ->
          Anal.prep!(%Rec{exclusive?: "barf"})
        end
      )
    end

    test ":exclusive? is true but no fields defined" do
      assert_raise(
        SpecError,
        ":required and/or :optional must be used if :exclusive? is true",
        fn ->
          Anal.prep!(%Rec{exclusive?: true})
        end
      )
    end

    test ":optional or :required is not a spec map" do
      [
        "goo",
        [],
        [key: "word"],
        9,
        nil,
        %{atom_key: %Anal.Str{}},
        %{"good" => "bad"},
        %{"good" => %{can_be_nil: true}}
      ]
      |> Enum.each(fn bad_val ->
        assert_raise(
          SpecError,
          ":optional must be a Map with string keys and Anal protocol-implementing values",
          fn -> Anal.prep!(%Rec{optional: bad_val}) end
        )

        assert_raise(
          SpecError,
          ":required must be a Map with string keys and Anal protocol-implementing values",
          fn -> Anal.prep!(%Rec{required: bad_val}) end
        )
      end)
    end

    test ":required and :optional field have the same key" do
      str_spec = %Anal.Str{}
      common = %{"a" => str_spec, "b" => str_spec}
      optional = Map.put(common, "c", str_spec)
      required = Map.put(common, "d", str_spec)

      assert_raise(
        SpecError,
        "the following keys were in both :optional and :required -- a, b",
        fn ->
          Anal.prep!(%Rec{optional: optional, required: required})
        end
      )
    end

    test ":optional or :required contains an invalid spec" do
      bad = %{"my_str" => %Anal.Str{min_length: -1}}

      assert_raise(
        SpecError,
        ":min_length must be a positive integer",
        fn ->
          Anal.prep!(%Rec{optional: bad})
        end
      )

      assert_raise(
        SpecError,
        ":min_length must be a positive integer",
        fn ->
          Anal.prep!(%Rec{required: bad})
        end
      )
    end
  end

  describe "Anal.prep!/1 a valid Rec" do
    @tag :it
    test "adds a default error message" do
      assert %Rec{error_message: "must be a record"} = Anal.prep!(%Rec{})

      required = %{"r1" => %Anal.Str{}, "r2" => %Anal.Boo{}}
      optional = %{"o1" => %Anal.Str{}, "o2" => %Anal.Boo{}}

      assert %Rec{error_message: "must be a record with the required keys \"r1\", \"r2\""} =
               Anal.prep!(%Rec{required: required})

      assert %Rec{error_message: "must be a record with only the required keys \"r1\", \"r2\""} =
               Anal.prep!(%Rec{required: required, exclusive?: true})

      assert %Rec{error_message: "must be a record with the optional keys \"o1\", \"o2\""} =
               Anal.prep!(%Rec{optional: optional})

      assert %Rec{error_message: "must be a record with only the optional keys \"o1\", \"o2\""} =
               Anal.prep!(%Rec{optional: optional, exclusive?: true})

      assert %Rec{
               error_message:
                 "must be a record with the required keys \"r1\", \"r2\" and the optional keys \"o1\", \"o2\""
             } = Anal.prep!(%Rec{optional: optional, required: required})

      assert %Rec{
               error_message:
                 "must be a record with only the required keys \"r1\", \"r2\" and the optional keys \"o1\", \"o2\""
             } = Anal.prep!(%Rec{optional: optional, required: required, exclusive?: true})
    end

    test "accepts an error message" do
      assert %Rec{error_message: "dammit"} = Anal.prep!(%Rec{error_message: "dammit"})
    end
  end

  describe "Anal.exam a valid Rec" do
    test "SpecError if the spec isn't prepped" do
      unprepped = %Rec{}

      assert_raise(
        SpecError,
        "you must call Anal.prep/1 on the spec before calling Anal.exam/2",
        fn ->
          Anal.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_spec = Anal.prep!(%Rec{nil_ok?: true})
      nil_not_ok_spec = Anal.prep!(%Rec{error_message: "dammit"})

      :ok = Anal.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Anal.exam(nil_not_ok_spec, nil)
    end

    test "error if not a map" do
      spec = Anal.prep!(%Rec{error_message: "dammit"})

      [
        true,
        1,
        "foo",
        [],
        {}
      ]
      |> Enum.each(fn val ->
        assert {:error, "dammit"} = Anal.exam(spec, val)
      end)

      assert :ok = Anal.exam(spec, %{})
    end

    test "with required fields" do
      required = %{"rs" => %Anal.Str{}, "rb" => %Anal.Boo{}}

      spec = Anal.prep!(%Rec{required: required})

      :ok = Anal.exam(spec, %{"rs" => "foo", "rb" => true})
      {:error, %{"rb" => "is required"}} = Anal.exam(spec, %{"rs" => "foo"})
    end

    test "with optional fields" do
      # required = %{"rs" => %Anal.Str{}, "rb" => %Anal.Boo{}}
      optional = %{"os" => %Anal.Str{}, "ob" => %Anal.Boo{}}

      spec = Anal.prep!(%Rec{optional: optional, error_message: "dammit"})

      :ok = Anal.exam(spec, %{"rs" => "foo", "rb" => true})
      :ok = Anal.exam(spec, %{"rb" => true})
      :ok = Anal.exam(spec, %{})
    end

    test "with exclusive?" do
      required = %{"r" => %Anal.Str{}}
      optional = %{"o" => %Anal.Str{}}

      spec = Anal.prep!(%Rec{required: required, optional: optional, error_message: "dammit"})
      exclusive_spec = Map.put(spec, :exclusive?, true)

      assert :ok = Anal.exam(spec, %{"r" => "foo", "other" => "thing"})
      assert :ok = Anal.exam(spec, %{"r" => "foo", "o" => "foo", "other" => "thing"})

      assert {:error, %{"other" => "is not allowed"}} =
               Anal.exam(exclusive_spec, %{"r" => "foo", "other" => "thing"})

      assert {:error, %{"other" => "is not allowed"}} =
               Anal.exam(exclusive_spec, %{"r" => "foo", "o" => "foo", "other" => "thing"})
    end

    test "detects nested errors" do
      required = %{"r" => %Anal.Str{error_message: "bad r"}}
      optional = %{"o" => %Anal.Str{error_message: "bad o"}}

      spec = Anal.prep!(%Rec{required: required, optional: optional})

      assert :ok = Anal.exam(spec, %{"r" => "foo", "other" => "thing"})
      assert :ok = Anal.exam(spec, %{"r" => "foo", "o" => "foo", "other" => "thing"})

      assert {:error, %{"r" => "bad r"}} = Anal.exam(spec, %{"r" => 1, "other" => 1})

      assert {:error, %{"o" => "bad o"}} =
               Anal.exam(spec, %{"r" => "foo", "o" => 1, "other" => 1})

      assert {:error, %{"r" => "bad r", "o" => "bad o"}} =
               Anal.exam(spec, %{"r" => 1, "o" => 1, "other" => 1})
    end

    test "detects deeply nested errors" do
      required = %{"r" => %Anal.Str{error_message: "bad r str"}}
      optional = %{"o" => %Anal.Str{error_message: "bad o str"}}

      nested_rec_spec = %Rec{
        required: required,
        optional: optional
      }

      spec =
        Anal.prep!(%Rec{
          required: %{"r" => Map.put(nested_rec_spec, :error_message, "bad r rec")},
          optional: %{"o" => Map.put(nested_rec_spec, :error_message, "bad o rec")}
        })

      assert :ok =
               Anal.exam(spec, %{
                 "r" => %{"r" => "foo", "o" => "foo", "x" => "?"},
                 "o" => %{"r" => "foo", "o" => "foo", "x" => "?"},
                 "x" => "?"
               })

      assert :ok =
               Anal.exam(spec, %{
                 "r" => %{"r" => "foo"},
                 "o" => %{"r" => "foo", "o" => "foo", "x" => "?"},
                 "x" => "?"
               })

      assert :ok = Anal.exam(spec, %{"r" => %{"r" => "foo"}})

      assert {:error, errors} =
               Anal.exam(spec, %{
                 "r" => %{"r" => 1, "o" => 1, "x" => "?"},
                 "o" => %{"o" => 1, "x" => "?"},
                 "x" => "?"
               })

      assert errors == %{
               "r" => %{"r" => "bad r str", "o" => "bad o str"},
               "o" => %{
                 "r" => "is required",
                 "o" => "bad o str"
               }
             }

      assert {:error, errors} = Anal.exam(spec, %{"o" => %{"o" => 1, "x" => "?"}, "x" => "?"})

      assert errors == %{
               "r" => "is required",
               "o" => %{
                 "r" => "is required",
                 "o" => "bad o str"
               }
             }

      assert {:error, errors} =
               Anal.exam(spec, %{"r" => 1, "o" => %{"o" => 1, "x" => "?"}, "x" => "?"})

      assert errors == %{
               "r" => "bad r rec",
               "o" => %{
                 "r" => "is required",
                 "o" => "bad o str"
               }
             }

      assert {:error, %{"r" => "bad r rec"}} = Anal.exam(spec, %{"r" => 1, "other" => 1})

      assert {:error, %{"o" => "bad o rec"}} =
               Anal.exam(spec, %{"r" => "foo", "o" => 1, "other" => 1})

      assert {:error, %{"r" => "bad r rec", "o" => "bad o rec"}} =
               Anal.exam(spec, %{"r" => 1, "o" => 1, "other" => 1})
    end
  end
end
