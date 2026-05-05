defmodule Argus.Repo.Migrations.CreateMetricPoints do
  use Ecto.Migration

  def change do
    create table(:metric_points) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :timestamp, :utc_datetime, null: false
      add :name, :string, null: false
      add :type, :string, null: false
      add :value, :float, null: false
      add :unit, :string
      add :trace_id, :string
      add :span_id, :string
      add :attributes, :map, null: false, default: %{}
      add :raw_payload, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:metric_points, [:project_id, :timestamp])
    create index(:metric_points, [:project_id, :name, :type, :timestamp])
    create index(:metric_points, [:project_id, :type])
  end
end
