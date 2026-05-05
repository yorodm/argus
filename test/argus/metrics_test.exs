defmodule Argus.MetricsTest do
  use Argus.DataCase, async: true

  alias Argus.Metrics
  alias Argus.Metrics.MetricPoint

  import Argus.WorkspaceFixtures

  describe "create_metric_points/2" do
    test "stores valid metric points and normalizes typed attributes" do
      project = project_fixture(team_fixture())
      timestamp = DateTime.utc_now(:second)

      assert {:ok, 1} =
               Metrics.create_metric_points(project, [
                 %{
                   "timestamp" => DateTime.to_unix(timestamp) + 0.7555397,
                   "trace_id" => "bb8e667ffaba4703bb9b10bc5ff7099f",
                   "span_id" => "b8a25c2fa7e15e4c",
                   "name" => "queue.depth",
                   "type" => "gauge",
                   "value" => 42,
                   "unit" => "item",
                   "attributes" => %{
                     "queue" => %{"value" => "default", "type" => "string"},
                     "active" => %{"value" => true, "type" => "boolean"}
                   }
                 }
               ])

      metric_point = Repo.one!(from(metric_point in MetricPoint))

      assert metric_point.project_id == project.id
      assert metric_point.timestamp == timestamp
      assert metric_point.name == "queue.depth"
      assert metric_point.type == :gauge
      assert metric_point.value == 42.0
      assert metric_point.unit == "item"
      assert metric_point.attributes == %{"queue" => "default", "active" => true}
    end

    test "ignores invalid metric rows without rejecting the batch" do
      project = project_fixture(team_fixture())

      assert {:ok, 1} =
               Metrics.create_metric_points(project, [
                 %{"name" => "valid.counter", "type" => "counter", "value" => 2},
                 %{"name" => "missing.value", "type" => "counter"},
                 %{"name" => "bad.type", "type" => "set", "value" => 1}
               ])

      assert Repo.one!(from metric_point in MetricPoint, select: metric_point.name) ==
               "valid.counter"
    end

    test "prunes raw metric points outside the retention window" do
      project = project_fixture(team_fixture())
      now = DateTime.utc_now(:second)
      old = DateTime.add(now, -31 * 86_400, :second)

      assert {:ok, 2} =
               Metrics.create_metric_points(project, [
                 %{
                   "timestamp" => DateTime.to_iso8601(old),
                   "name" => "old",
                   "type" => "counter",
                   "value" => 1
                 },
                 %{
                   "timestamp" => DateTime.to_iso8601(now),
                   "name" => "new",
                   "type" => "counter",
                   "value" => 1
                 }
               ])

      assert Repo.all(from metric_point in MetricPoint, select: metric_point.name) == ["new"]
    end
  end

  describe "chart_data/2" do
    test "aggregates counters into time buckets" do
      project = project_fixture(team_fixture())
      timestamp = DateTime.utc_now(:second) |> DateTime.add(-120, :second)

      assert {:ok, 2} =
               Metrics.create_metric_points(project, [
                 %{
                   "timestamp" => DateTime.to_iso8601(timestamp),
                   "name" => "button_click",
                   "type" => "counter",
                   "value" => 5
                 },
                 %{
                   "timestamp" => DateTime.to_iso8601(timestamp),
                   "name" => "button_click",
                   "type" => "counter",
                   "value" => 3
                 }
               ])

      assert %{
               name: "button_click",
               type: :counter,
               buckets: [%{sum: 8.0, count: 2}]
             } =
               Metrics.chart_data(project, %{
                 "name" => "button_click",
                 "type" => "counter",
                 "window" => "1h"
               })
    end
  end
end
