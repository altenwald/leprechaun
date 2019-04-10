defmodule Leprechaun.Repo.Migrations.CreateHiScore do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:hi_score, engine: :set) do
      add :name, :string
      add :score, :integer
      add :turns, :integer
      add :extra_turns, :integer
      add :remote_ip, :string

      timestamps()
    end
  end
end
