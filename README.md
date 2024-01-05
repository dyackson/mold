# Mold

**A validator for decoded json**

## Examples

### Basic usage

```elixir
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

:ok = Mold.exam(mold, valid_data)

invalid_data = %{"my_int" => -1, "my_str" => "bla", "my_lst" => ["a", 2, "c"]}

{:error, error_map} = Mold.exam(mold, invalid_data)

error_map == %{
 "my_int" => "must be an integer greater than or equal to 0",
 "my_str" => "must be one of these strings (with matching case): \"foo\", \"bar\"",
 "my_lst" => %{1 => "must be a string"}
}
```

### Macros for creating molds with fewer keystrokes

```elixir
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

created_with_macros == created_without_macros
```

### Molds must be prepped before use

```elixir
Mold.exam(%Mold.Int{}, 1)
# ** (Mold.Error) you must call Mold.prep/1 on the mold before calling Mold.exam/2

# Mold.prep!\1 ensures that you're using the library correctly.
Mold.prep!(%Mold.Int{lt: true})
# ** (Mold.Error) :lt must be an integer

# Mold.prep! prevents you from creating a mold that can't be satisfied
Mold.prep!(%Mold.Rec{required: %{"my_int" => %Mold.Int{gt: 4, lt: 1}}})
# ** (Mold.Error) :gt must be less than :lt
```

### Default error messages can be understood by an end user
Mold generates error messages for all mold structs based on their parameters.
The conflated demo at the end of the README for examples.

```elixir
# Mold.prep!\1 pre-computes error messages
mold = %Mold.Int{gte: 0, lt: 100, nil_ok?: true}

assert %Mold.Int{
         error_message:
           "if not nil, must be an integer greater than or equal to 0 and less than 100" = err_msg
       } = Mold.prep!(mold)

{:error, ^err_msg} = Mold.exam(mold, -1)
```

### You can use your own error messages if you prefer

```elixir
custom_error_message = "gotta be from 0-99 or null"

assert %Mold.Int{error_message: ^custom_error_message} =
         mold =
         Mold.prep!(%Mold.Int{
           gte: 0,
           lt: 100,
           nil_ok?: true,
           error_message: custom_error_message
         })

assert {:error, ^custom_error_message} = Mold.exam(mold, -1)

{:error, ^custom_error_message = Mold.exam(mold, -1)
```

### A conflated example that shows a lot of features

```elixir
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

:ok = Mold.exam(user_mold, valid_user)

# errors when data has invalid top-level fields
invalid_user =
  Map.merge(valid_user, %{
    "first_name" => nil,
    "lucky_numbers" => [1, 2],
    "gender" => "woman",
    "temperature" => "-100"
  })

{:error, error_map} = Mold.exam(user_mold, invalid_user)

error_map == %{
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

{:error, error_map} = Mold.exam(user_mold, invalid_user)

error_map == %{
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

{:error, error_map} = Mold.exam(user_mold, invalid_user)

error_map == %{
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
