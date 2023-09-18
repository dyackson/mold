# Mold

**A validator for decoded json**

## Examples

ExDoc are in the works, but here are annotated examples:

```elixir
    # A mold describes the shape of data.
    # It's only for data types that could have been parsed from JSON
    mold = %Mold.Rec{
      required: %{
        "my_int" => %Mold.Int{min: 0},
        "my_str" => %Mold.Str{one_of: ["foo", "bar", "who"]}
      }
    }

    assert_raise(
      Mold.Error,
      "you must call Mold.prep/1 on the mold before calling Mold.exam/2",
      fn ->
        Mold.exam(mold, %{"my_int" => 1, "my_str" => "foo"})
      end
    )

    # Mold.prep!/1 ensures that you're using the library correctly.
    assert_raise(
      Mold.Error,
      ":required must be a Map with string keys and Mold protocol-implementing values",
      fn ->
        bad_mold = %Mold.Rec{required: ["name", "age"]}
        Mold.prep!(bad_mold)
      end
    )

    # And prevents you from creating an impossible mold
    assert_raise(Mold.Error, ":gt must be less than :lt", fn ->
      bad_mold = %Mold.Rec{required: %{"my_int" => %Mold.Int{gt: 4, lt: 1}}}
      Mold.prep!(bad_mold)
    end)

    # It also pre-computes error messages
    assert %Mold.Int{
             error_message:
               "if not nil, must be an integer greater than or equal to 0 and less than 100"
           } = Mold.prep!(%Mold.Int{gte: 0, lt: 100, nil_ok?: true})

    # Or you can use your own
    custom_error_message = "gotta be from 0-99 or null"

    assert %Mold.Int{error_message: ^custom_error_message} =
             Mold.prep!(%Mold.Int{
               gte: 0,
               lt: 100,
               nil_ok?: true,
               error_message: custom_error_message
             })

    # Let's prep and use a valid mold for describing a user for a music+health+pets app
    user_mold = %Mold.Rec{
      required: %{
        "first_name" => %Mold.Str{},
        "last_name" => %Mold.Str{},
        "middle_initial" => %Mold.Str{nil_ok?: true, max: 1},
        # all molds have a :but field that allows for custom logic
        "date_of_birth" => %Mold.Str{
          but: fn it -> match?({:ok, _}, Date.from_iso8601(it)) end,
          error_message: "must be formatted yyyy-mm-dd"
        },
        "id" => %Mold.Str{
          regex: ~r/^[0-f]{5}$/,
          error_message: "must be a a length 5 hex string"
        },
        "lucky_numbers" => %Mold.Lst{of: %Mold.Int{}, min: 3}
      },
      optional: %{
        "gender" => %Mold.Str{one_of: ["male", "female", "non-binary"], nil_ok?: true},
        "temperature" => %Mold.Dec{gt: 0},
        "pets" => %Mold.Lst{
          of: %Mold.Rec{
            required: %{
              "name" => %Mold.Str{},
              "species" => %Mold.Str{},
              "is_rescue" => %Mold.Boo{}
            }
          }
        },
        "favorite_songs_by_genre" => %Mold.Dic{
          keys: %Mold.Str{min: 4},
          vals: %Mold.Rec{
            required: %{"artist" => %Mold.Str{}, "title" => %Mold.Str{}},
            optional: %{
              "year" => %Mold.Int{gte: 1900, lte: 2025}
            }
          }
        },
        "anything_else" => %Mold.Any{}
      }
    }

    # prep! recusively preps nested molds
    user_mold = Mold.prep!(user_mold)

    user = %{
      "first_name" => "Cornelius",
      "last_name" => "Adoab",
      "middle_initial" => "R",
      "id" => "a9bf0",
      "date_of_birth" => "1915-12-14",
      "lucky_numbers" => [1, 2, 3],
      "gender" => nil,
      "pets" => [
        %{"name" => "Bilton", "species" => "badger", "is_rescue" => false},
        %{"name" => "Sledrick", "species" => "snake", "is_rescue" => true}
      ],
      "temperature" => "103.9",
      "favorite_songs_by_genre" => %{
        "bluegrass" => %{"title" => "Glendale Train", "artist" => "New Riders of the Purple Sage"},
        "80s Athens, GA rock" => %{"title" => "Radio Free Europe", "artist" => "REM"}
      }
    }

    # Call Mold.exam/2 to see if data is valid
    # It returns :ok or an error-tuple
    # When data is valid
    assert :ok = Mold.exam(user_mold, user)

    # An errors when data has invalid top-level fields
    invalid_user =
      Map.merge(user, %{
        "first_name" => nil,
        "lucky_numbers" => [1, 2],
        "gender" => "woman",
        "temperature" => "-100"
      })

    assert {:error, error_map} = Mold.exam(user_mold, invalid_user)

    assert error_map == %{
             "first_name" => "must be a string",
             "lucky_numbers" =>
               "must be a list with at least 3 elements, each of which must be an integer",
             "gender" =>
               "if not nil, must be one of these strings (with matching case): \"male\", \"female\", \"non-binary\"",
             "temperature" => "must be a decimal-formatted string greater than 0"
           }

    # error when data has invalid nested fields
    invalid_user =
      user
      |> Map.put("lucky_numbers", ["seven", 2, "3.14"])
      |> update_in(["pets"], fn pets ->
        ["Steve", %{"name" => "Larry", "species" => true} | pets]
      end)
      |> put_in(["favorite_songs_by_genre", "bluegrass", "title"], nil)

    assert {:error, error_map} = Mold.exam(user_mold, invalid_user)

    assert error_map ==
             %{
               "lucky_numbers" => %{
                 0 => "must be an integer",
                 2 => "must be an integer"
               },
               "pets" => %{
                 0 =>
                   "must be a record with the required keys \"is_rescue\", \"name\", \"species\"",
                 1 => %{"species" => "must be a string", "is_rescue" => "is required"}
               },
               "favorite_songs_by_genre" => %{"bluegrass" => %{"title" => "must be a string"}}
             }

    # error when Dic[tionary] keys are invalid
    invalid_user =
      put_in(user, ["favorite_songs_by_genre", "rap"], %{
        "group" => "Outkast",
        "title" => "Elevators"
      })

    assert {:error, error_map} = Mold.exam(user_mold, invalid_user)

    assert error_map == %{
             "favorite_songs_by_genre" => %{
               :__key_errors__ => %{
                 message: "must be a string with at least 4 characters",
                 keys: ["rap"]
               },
               # errors in the value for a bad key are also reported
               "rap" => %{"artist" => "is required"}
             }
           }
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/payload_validator](https://hexdocs.pm/payload_validator).

