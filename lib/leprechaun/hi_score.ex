defmodule Leprechaun.HiScore do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  alias Leprechaun.{HiScore, Repo}

  @top_num 20

  schema "hi_score" do
    field :name
    field :score,       :integer
    field :turns,       :integer
    field :extra_turns, :integer
    field :remote_ip

    timestamps()
  end

  @required_fields [:name, :score, :turns, :extra_turns]
  @optional_fields []

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  def save(name, score, turns, extra_turns, remote_ip) do
    changeset(%HiScore{}, %{"name" => name,
                            "score" => score,
                            "turns" => turns,
                            "extra_turns" => extra_turns,
                            "remote_ip" => remote_ip})
    |> Repo.insert()
  end

  defp get_order_index([]), do: {:error, :notfound}
  defp get_order_index([{%HiScore{}, order}|_]), do: {:ok, order}

  def get_order(my_id) do
    from(h in HiScore, order_by: [desc: h.score])
    |> Repo.all()
    |> Enum.with_index(1)
    |> Enum.filter(fn {%HiScore{id: id}, _} -> id == my_id end)
    |> get_order_index()
  end

  def top_list do
    from(h in HiScore, order_by: [desc: h.score], limit: @top_num)
    |> Repo.all()
  end
end
