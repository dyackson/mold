defmodule Mold.MoldTest do
  use ExUnit.Case
  import Mold

  test "basic usage" do
    # define a struct for validating data
    mold =
      %Mold.Rec{
        required: %{
          "my_int" => %Mold.Int{gte: 0},
          "my_str" => %Mold.Str{one_of: ["foo", "bar"]}
        },
        optional: %{
          "my_lst" => %Mold.Lst{of: %Mold.Str{}}
        }
      }
      |> Mold.prep!()

    # use Mold.exam/2 to valide data against a mold

    valid_data = %{"my_int" => 1, "my_str" => "foo"}

    assert :ok = Mold.exam(mold, valid_data)

    invalid_data = %{"my_int" => -1, "my_str" => "bla", "my_lst" => ["a", 2, "c"]}

    assert {:error, error_map} = Mold.exam(mold, invalid_data)

    assert error_map == %{
             "my_int" => "must be an integer greater than or equal to 0",
             "my_str" => "must be one of these strings (with matching case): \"foo\", \"bar\"",
             "my_lst" => %{1 => "must be a string"}
           }
  end

  test "there are macros for creating any mold struct with fewer keystrokes" do
    created_without_macros = %Mold.Rec{
      required: %{
        "my_int" => %Mold.Int{gte: 0},
        "my_str" => %Mold.Str{one_of: ["foo", "bar"]}
      },
      optional: %{
        "my_lst" => %Mold.Lst{of: %Mold.Str{}}
      }
    }

    created_with_macros =
      rec(
        required: %{
          "my_int" => int(gte: 0),
          "my_str" => str(one_of: ["foo", "bar"])
        },
        optional: %{
          "my_lst" => lst(of: str())
        }
      )

    assert created_with_macros == created_without_macros
  end

  test "Recs must be prepped before use" do
    unprepped_mold = %Mold.Int{lt: 100}

    assert_raise(
      Mold.Error,
      "you must call Mold.prep/1 on the mold before calling Mold.exam/2",
      fn -> Mold.exam(unprepped_mold, 1) end
    )

    # Mold.prep!\1 ensures that you're using the library correctly.
    bad_mold = %Mold.Int{lt: true}

    assert_raise(
      Mold.Error,
      ":lt must be an integer",
      fn -> Mold.prep!(bad_mold) end
    )

    # Mold.prep! prevents you from creating mold that can't be satisfied
    impossible_mold = %Mold.Rec{required: %{"my_int" => %Mold.Int{gt: 4, lt: 1}}}

    assert_raise(Mold.Error, ":gt must be less than :lt", fn ->
      Mold.prep!(impossible_mold)
    end)

    # Mold.prep!\1 pre-computes error messages
    mold = %Mold.Int{gte: 0, lt: 100, nil_ok?: true}

    assert %Mold.Int{
             error_message:
               "if not nil, must be an integer greater than or equal to 0 and less than 100"
           } = Mold.prep!(mold)

    # you can also supply a custom error message
    custom_error_message = "gotta be from 0-99 or null"

    assert %Mold.Int{error_message: ^custom_error_message} =
             mold =
             Mold.prep!(%Mold.Int{
               gte: 0,
               lt: 100,
               nil_ok?: true,
               error_message: custom_error_message
             })

    assert {:error, ^custom_error_message} = Mold.exam(mold, 101)
  end

  test "A mold that uses all the types" do
    songs_by_genre_mold =
      dic(
        keys: str(min: 4),
        vals:
          rec(
            required: %{"artist" => str(), "title" => str()},
            optional: %{
              "year" => int(gte: 1900, lte: 2025)
            }
          )
      )

    user_mold =
      rec(
        required: %{
          "first_name" => str(),
          "last_name" => str(),
          "middle_initial" => str(nil_ok?: true, max: 1),
          # all molds have a :but field that allows for custom logic
          "date_of_birth" =>
            str(
              but: fn it -> match?({:ok, _}, Date.from_iso8601(it)) end,
              error_message: "must be formatted yyyy-mm-dd"
            ),
          "id" =>
            str(
              regex: ~r/^[0-f]{5}$/,
              error_message: "must be a a length 5 hex string"
            ),
          "lucky_numbers" => lst(of: int(), min: 3)
        },
        optional: %{
          "gender" => str(one_of: ["male", "female", "non-binary"], nil_ok?: true),
          "temperature" => dec(gt: 0),
          "pets" =>
            lst(of: rec(required: %{"name" => str(), "species" => str(), "is_rescue" => boo()})),
          "favorite_songs_by_genre" => songs_by_genre_mold,
          "anything_else" => any()
        }
      )

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
  end

  test "mold macros" do
    assert int(gte: 1) == %Mold.Int{gte: 1}
    assert int() == %Mold.Int{}

    assert str(min: 1) == %Mold.Str{min: 1}
    assert str() == %Mold.Str{}

    assert lst(min: 1) == %Mold.Lst{min: 1}
    assert lst() == %Mold.Lst{}

    assert boo(nil_ok?: true) == %Mold.Boo{nil_ok?: true}
    assert boo() == %Mold.Boo{}

    assert any(nil_ok?: true) == %Mold.Any{nil_ok?: true}
    assert any() == %Mold.Any{}

    assert dec(lte: 1) == %Mold.Dec{lte: 1}
    assert dec() == %Mold.Dec{}

    assert rec(required: %{"foo" => any()}) == %Mold.Rec{required: %{"foo" => %Mold.Any{}}}
    assert rec() == %Mold.Rec{}

    assert dic(keys: str(), vals: int()) == %Mold.Dic{keys: %Mold.Str{}, vals: %Mold.Int{}}
    assert dic() == %Mold.Dic{}
  end

  test "random test with macros" do
    # Let's prep and use a valid mold for describing a user for a music+health+pets app
    pet_mold = rec(required: %{"name" => str(), "species" => str(), "is_rescue" => boo()})

    # A Dic (short for "Dictionary") describes a hash map
    song_by_genre_mold =
      dic(
        keys: str(min: 4),
        vals:
          rec(
            required: %{"artist" => str(), "title" => str()},
            optional: %{"year" => int(gte: 1900, lte: 2025)}
          )
      )

    user_mold =
      rec(
        required: %{
          "first_name" => str(),
          "last_name" => str(),
          "middle_initial" => str(nil_ok?: true, max: 1),
          # all molds have a :but field that allows for custom logic
          "date_of_birth" =>
            str(
              but: fn it -> match?({:ok, _}, Date.from_iso8601(it)) end,
              error_message: "must be formatted yyyy-mm-dd"
            ),
          "id" =>
            str(
              regex: ~r/^[0-f]{5}$/,
              error_message: "must be a a length 5 hex string"
            ),
          "lucky_numbers" => lst(of: int(), min: 3)
        },
        optional: %{
          "gender" => str(one_of: ["male", "female", "non-binary"], nil_ok?: true),
          "temperature" => dec(gt: 0),
          "pets" => lst(of: pet_mold),
          "favorite_songs_by_genre" => song_by_genre_mold,
          "anything_else" => any()
        }
      )

    # prep! recusively preps nested molds
    user_mold = Mold.prep!(user_mold)

    valid_user = %{
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

    assert :ok = Mold.exam(user_mold, valid_user)

    # An errors when data has invalid top-level fields
    invalid_user =
      Map.merge(valid_user, %{
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
      valid_user
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
      put_in(valid_user, ["favorite_songs_by_genre", "rap"], %{
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
  end
end
