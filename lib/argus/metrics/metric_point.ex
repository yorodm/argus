defmodule Argus.Metrics.MetricPoint do
  use Ecto.Schema
  import Ecto.Changeset

  @types [:counter, :gauge, :distribution]

  schema "metric_points" do
    field :timestamp, :utc_datetime
    field :name, :string
    field :type, Ecto.Enum, values: @types
    field :value, :float
    field :unit, :string
    field :trace_id, :string
    field :span_id, :string
    field :attributes, :map, default: %{}
    field :raw_payload, :map, default: %{}

    belongs_to :project, Argus.Projects.Project

    timestamps(type: :utc_datetime)
  end

  def types, do: @types

  def changeset(metric_point, attrs) do
    metric_point
    |> cast(attrs, [
      :project_id,
      :timestamp,
      :name,
      :type,
      :value,
      :unit,
      :trace_id,
      :span_id,
      :attributes,
      :raw_payload
    ])
    |> validate_required([:project_id, :timestamp, :name, :type, :value])
    |> validate_number(:value, greater_than_or_equal_to: -1.0e308, less_than_or_equal_to: 1.0e308)
  end
end
