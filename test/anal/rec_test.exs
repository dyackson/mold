defmodule Mold.RecTest do
  alias Mold.SpecError
  alias Mold.Rec

  use ExUnit.Case

  describe "Mold.prep! a Rec raises a SpecError when" do
    test "nil_ok? not a boolean" do
      assert_raise(SpecError, ":nil_ok? must be a boolean", fn ->
        Mold.prep!(%Rec{nil_ok?: "yuh"})
      end)
    end

    test ":also is not an arity-1 function" do
      assert_raise(SpecError, ":also must be an arity-1 function that returns a boolean", fn ->
        Mold.prep!(%Rec{also: &(&1 + &2)})
      end)
    end

    test ":exclusive? is not a boolean" do
      assert_raise(
        SpecError,
        ":exclusive? must be a boolean",
        fn ->
          Mold.prep!(%Rec{exclusive?: "barf"})
        end
      )
    end

    test ":exclusive? is true but no fields defined" do
      assert_raise(
        SpecError,
        ":required and/or :optional must be used if :exclusive? is true",
        fn ->
          Mold.prep!(%Rec{exclusive?: true})
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
        %{atom_key: %Mold.Str{}},
        %{"good" => "bad"},
        %{"good" => %{can_be_nil: true}}
      ]
      |> Enum.each(fn bad_val ->
        assert_raise(
          SpecError,
          ":optional must be a Map with string keys and Mold protocol-implementing values",
          fn -> Mold.prep!(%Rec{optional: bad_val}) end
        )

        assert_raise(
          SpecError,
          ":required must be a Map with string keys and Mold protocol-implementing values",
          fn -> Mold.prep!(%Rec{required: bad_val}) end
        )
      end)
    end

    test ":required and :optional field have the same key" do
      str_spec = %Mold.Str{}
      common = %{"a" => str_spec, "b" => str_spec}
      optional = Map.put(common, "c", str_spec)
      required = Map.put(common, "d", str_spec)

      assert_raise(
        SpecError,
        "the following keys were in both :optional and :required -- a, b",
        fn ->
          Mold.prep!(%Rec{optional: optional, required: required})
        end
      )
    end

    test ":optional or :required contains an invalid spec" do
      bad = %{"my_str" => %Mold.Str{min_length: -1}}

      assert_raise(
        SpecError,
        ":min_length must be a positive integer",
        fn ->
          Mold.prep!(%Rec{optional: bad})
        end
      )

      assert_raise(
        SpecError,
        ":min_length must be a positive integer",
        fn ->
          Mold.prep!(%Rec{required: bad})
        end
      )
    end
  end

  describe "Mold.prep!/1 a valid Rec" do
    @tag :it
    test "adds a default error message" do
      assert %Rec{error_message: "must be a record"} = Mold.prep!(%Rec{})

      required = %{"r1" => %Mold.Str{}, "r2" => %Mold.Boo{}}
      optional = %{"o1" => %Mold.Str{}, "o2" => %Mold.Boo{}}

      assert %Rec{error_message: "must be a record with the required keys \"r1\", \"r2\""} =
               Mold.prep!(%Rec{required: required})

      assert %Rec{error_message: "must be a record with only the required keys \"r1\", \"r2\""} =
               Mold.prep!(%Rec{required: required, exclusive?: true})

      assert %Rec{error_message: "must be a record with the optional keys \"o1\", \"o2\""} =
               Mold.prep!(%Rec{optional: optional})

      assert %Rec{error_message: "must be a record with only the optional keys \"o1\", \"o2\""} =
               Mold.prep!(%Rec{optional: optional, exclusive?: true})

      assert %Rec{
               error_message:
                 "must be a record with the required keys \"r1\", \"r2\" and the optional keys \"o1\", \"o2\""
             } = Mold.prep!(%Rec{optional: optional, required: required})

      assert %Rec{
               error_message:
                 "must be a record with only the required keys \"r1\", \"r2\" and the optional keys \"o1\", \"o2\""
             } = Mold.prep!(%Rec{optional: optional, required: required, exclusive?: true})
    end

    test "accepts an error message" do
      assert %Rec{error_message: "dammit"} = Mold.prep!(%Rec{error_message: "dammit"})
    end
  end

  describe "Mold.exam a valid Rec" do
    test "SpecError if the spec isn't prepped" do
      unprepped = %Rec{}

      assert_raise(
        SpecError,
        "you must call Mold.prep/1 on the spec before calling Mold.exam/2",
        fn ->
          Mold.exam(unprepped, true)
        end
      )
    end

    test "allows nil iff nil_ok?" do
      nil_ok_spec = Mold.prep!(%Rec{nil_ok?: true})
      nil_not_ok_spec = Mold.prep!(%Rec{error_message: "dammit"})

      :ok = Mold.exam(nil_ok_spec, nil)
      {:error, "dammit"} = Mold.exam(nil_not_ok_spec, nil)
    end

    test "error if not a map" do
      spec = Mold.prep!(%Rec{error_message: "dammit"})

      [
        true,
        1,
        "foo",
        [],
        {}
      ]
      |> Enum.each(fn val ->
        assert {:error, "dammit"} = Mold.exam(spec, val)
      end)

      assert :ok = Mold.exam(spec, %{})
    end

    test "with required fields" do
      required = %{"rs" => %Mold.Str{}, "rb" => %Mold.Boo{}}

      spec = Mold.prep!(%Rec{required: required})

      :ok = Mold.exam(spec, %{"rs" => "foo", "rb" => true})
      {:error, %{"rb" => "is required"}} = Mold.exam(spec, %{"rs" => "foo"})
    end

    test "with optional fields" do
      # required = %{"rs" => %Mold.Str{}, "rb" => %Mold.Boo{}}
      optional = %{"os" => %Mold.Str{}, "ob" => %Mold.Boo{}}

      spec = Mold.prep!(%Rec{optional: optional, error_message: "dammit"})

      :ok = Mold.exam(spec, %{"rs" => "foo", "rb" => true})
      :ok = Mold.exam(spec, %{"rb" => true})
      :ok = Mold.exam(spec, %{})
    end

    test "with exclusive?" do
      required = %{"r" => %Mold.Str{}}
      optional = %{"o" => %Mold.Str{}}

      spec = Mold.prep!(%Rec{required: required, optional: optional, error_message: "dammit"})
      exclusive_spec = Map.put(spec, :exclusive?, true)

      assert :ok = Mold.exam(spec, %{"r" => "foo", "other" => "thing"})
      assert :ok = Mold.exam(spec, %{"r" => "foo", "o" => "foo", "other" => "thing"})

      assert {:error, %{"other" => "is not allowed"}} =
               Mold.exam(exclusive_spec, %{"r" => "foo", "other" => "thing"})

      assert {:error, %{"other" => "is not allowed"}} =
               Mold.exam(exclusive_spec, %{"r" => "foo", "o" => "foo", "other" => "thing"})
    end

    test "detects nested errors" do
      required = %{"r" => %Mold.Str{error_message: "bad r"}}
      optional = %{"o" => %Mold.Str{error_message: "bad o"}}

      spec = Mold.prep!(%Rec{required: required, optional: optional})

      assert :ok = Mold.exam(spec, %{"r" => "foo", "other" => "thing"})
      assert :ok = Mold.exam(spec, %{"r" => "foo", "o" => "foo", "other" => "thing"})

      assert {:error, %{"r" => "bad r"}} = Mold.exam(spec, %{"r" => 1, "other" => 1})

      assert {:error, %{"o" => "bad o"}} =
               Mold.exam(spec, %{"r" => "foo", "o" => 1, "other" => 1})

      assert {:error, %{"r" => "bad r", "o" => "bad o"}} =
               Mold.exam(spec, %{"r" => 1, "o" => 1, "other" => 1})
    end

    test "detects deeply nested errors" do
      required = %{"r" => %Mold.Str{error_message: "bad r str"}}
      optional = %{"o" => %Mold.Str{error_message: "bad o str"}}

      nested_rec_spec = %Rec{
        required: required,
        optional: optional
      }

      spec =
        Mold.prep!(%Rec{
          required: %{"r" => Map.put(nested_rec_spec, :error_message, "bad r rec")},
          optional: %{"o" => Map.put(nested_rec_spec, :error_message, "bad o rec")}
        })

      assert :ok =
               Mold.exam(spec, %{
                 "r" => %{"r" => "foo", "o" => "foo", "x" => "?"},
                 "o" => %{"r" => "foo", "o" => "foo", "x" => "?"},
                 "x" => "?"
               })

      assert :ok =
               Mold.exam(spec, %{
                 "r" => %{"r" => "foo"},
                 "o" => %{"r" => "foo", "o" => "foo", "x" => "?"},
                 "x" => "?"
               })

      assert :ok = Mold.exam(spec, %{"r" => %{"r" => "foo"}})

      assert {:error, errors} =
               Mold.exam(spec, %{
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

      assert {:error, errors} = Mold.exam(spec, %{"o" => %{"o" => 1, "x" => "?"}, "x" => "?"})

      assert errors == %{
               "r" => "is required",
               "o" => %{
                 "r" => "is required",
                 "o" => "bad o str"
               }
             }

      assert {:error, errors} =
               Mold.exam(spec, %{"r" => 1, "o" => %{"o" => 1, "x" => "?"}, "x" => "?"})

      assert errors == %{
               "r" => "bad r rec",
               "o" => %{
                 "r" => "is required",
                 "o" => "bad o str"
               }
             }

      assert {:error, %{"r" => "bad r rec"}} = Mold.exam(spec, %{"r" => 1, "other" => 1})

      assert {:error, %{"o" => "bad o rec"}} =
               Mold.exam(spec, %{"r" => "foo", "o" => 1, "other" => 1})

      assert {:error, %{"r" => "bad r rec", "o" => "bad o rec"}} =
               Mold.exam(spec, %{"r" => 1, "o" => 1, "other" => 1})
    end
  end
end
