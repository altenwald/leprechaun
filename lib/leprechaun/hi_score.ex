defmodule Leprechaun.HiScore do
  @moduledoc """
  Stores the HighScore for the user and all of the information about its game.
  """
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  alias Leprechaun.{Game, HiScore, Repo}

  @top_num 20

  @typedoc """
  The position a player achieved inside of the High Score table.
  """
  @type position() :: non_neg_integer()

  @typedoc """
  The ID inside of the High Score table.
  """
  @type hi_score_id() :: non_neg_integer()

  @typedoc """
  The information to be stored in the High Score table.
  """
  @type t() :: %__MODULE__{
          id: hi_score_id(),
          name: String.t(),
          score: non_neg_integer(),
          turns: non_neg_integer(),
          extra_turns: non_neg_integer(),
          remote_ip: String.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "hi_score" do
    field(:name)
    field(:score, :integer)
    field(:turns, :integer)
    field(:extra_turns, :integer)
    field(:remote_ip)

    timestamps()
  end

  @required_fields [:name, :score, :turns, :extra_turns]
  @optional_fields [:remote_ip]

  @doc false
  def changeset(model, params) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  @doc """
  Store a High Score entry providing information from the user and the game.
  """
  @spec save(
          Game.username(),
          Game.score(),
          Game.turns(),
          extra_turns :: Game.turns(),
          Game.remote_ip()
        ) :: {:ok, t()} | {:error, term}
  def save(name, score, turns, extra_turns, remote_ip) do
    changeset(%HiScore{}, %{
      "name" => name,
      "score" => score,
      "turns" => turns,
      "extra_turns" => extra_turns,
      "remote_ip" => remote_ip
    })
    |> Repo.insert()
  end

  defp get_order_index(nil), do: nil
  defp get_order_index({%HiScore{}, order}), do: order

  @doc """
  Get the order in the High Score table for a giving ID. This
  function is retrieving the whole table, ordering based on
  the score in descending order and adding an index to know
  the position of each one.
  """
  @spec get_order(hi_score_id()) :: position() | nil
  def get_order(my_id) do
    from(h in HiScore, order_by: [desc: h.score])
    |> Repo.all()
    |> Enum.with_index(1)
    |> Enum.find(fn {%HiScore{id: id}, _} -> id == my_id end)
    |> get_order_index()
  end

  @doc """
  Retrieve the top list of the High Score. The default number of
  elements is #{@top_num}.
  """
  @spec top_list() :: [t()]
  def top_list do
    from(h in HiScore, order_by: [desc: h.score], limit: @top_num)
    |> Repo.all()
  end
end
