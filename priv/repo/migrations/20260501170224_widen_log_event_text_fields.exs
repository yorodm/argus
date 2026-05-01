defmodule Argus.Repo.Migrations.WidenLogEventTextFields do
  use Ecto.Migration

  def change do
    alter table(:log_events) do
      modify :message, :text, null: false
      modify :message_template, :text
    end
  end
end
