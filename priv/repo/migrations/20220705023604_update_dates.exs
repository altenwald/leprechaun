defmodule Leprechaun.Repo.Migrations.UpdateDates do
  use Ecto.Migration

  def up do
    for key <- :mnesia.dirty_all_keys(:hi_score) do
      [{:hi_score, id, name, score, turns, extra_turns, remote_ip, inserted_at, updated_at}] =
        :mnesia.dirty_read(:hi_score, key)
      inserted_at =
        case inserted_at do
          {_, {_, _, _}} -> NaiveDateTime.from_erl!(inserted_at)
          {date, {h, m, s, microsecs}} -> NaiveDateTime.from_erl!({date, {h, m, s}}, {microsecs, 6})
          inserted_at -> inserted_at
        end

      updated_at =
        case updated_at do
          {_, {_, _, _}} -> NaiveDateTime.from_erl!(updated_at)
          {date, {h, m, s, microsecs}} -> NaiveDateTime.from_erl!({date, {h, m, s}}, {microsecs, 6})
          updated_at -> updated_at
        end

      :mnesia.dirty_write({:hi_score, id, name, score, turns, extra_turns, remote_ip, inserted_at, updated_at})
    end
  end

  def down do
  end
end
