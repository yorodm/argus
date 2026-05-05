defmodule Argus.Metrics do
  @moduledoc """
  Sentry trace metric storage and chart-oriented querying.

  The Sentry SDK sends metrics as lightweight telemetry points. Argus stores raw points for
  a short retention window and aggregates them when rendering project charts.
  """

  import Ecto.Query, warn: false

  alias Argus.Metrics.MetricPoint
  alias Argus.Projects.Project
  alias Argus.Repo

  @default_page_size 50
  @default_retention_days 30
  @windows %{
    "1h" => %{seconds: 3_600, bucket: "minute"},
    "24h" => %{seconds: 86_400, bucket: "hour"},
    "7d" => %{seconds: 604_800, bucket: "day"}
  }

  def window_options do
    [
      {"Last hour", "1h"},
      {"Last 24 hours", "24h"},
      {"Last 7 days", "7d"}
    ]
  end

  def metric_type_options do
    [
      {"Auto type", ""},
      {"Counter", "counter"},
      {"Gauge", "gauge"},
      {"Distribution", "distribution"}
    ]
  end

  def create_metric_point(%Project{} = project, attrs) when is_map(attrs) do
    %MetricPoint{}
    |> MetricPoint.changeset(Map.put(attrs, :project_id, project.id))
    |> Repo.insert()
  end

  def create_metric_points(%Project{} = project, items) when is_list(items) do
    now = DateTime.utc_now(:second)

    rows =
      items
      |> Enum.map(&insert_row(project, &1, now))
      |> Enum.reject(&is_nil/1)

    {count, _result} =
      if rows == [] do
        {0, nil}
      else
        Repo.insert_all(MetricPoint, rows)
      end

    prune_expired_metric_points(project)
    {:ok, count}
  end

  def create_metric_points(%Project{} = project, _items) do
    prune_expired_metric_points(project)
    {:ok, 0}
  end

  def list_metric_names(%Project{id: project_id}) do
    Repo.all(
      from metric_point in MetricPoint,
        where: metric_point.project_id == ^project_id,
        distinct: metric_point.name,
        order_by: [asc: metric_point.name],
        select: metric_point.name
    )
  end

  def latest_metric(%Project{id: project_id}) do
    Repo.one(
      from metric_point in MetricPoint,
        where: metric_point.project_id == ^project_id,
        order_by: [desc: metric_point.timestamp, desc: metric_point.id],
        limit: 1,
        select: %{name: metric_point.name, type: metric_point.type}
    )
  end

  def latest_metric(%Project{id: project_id}, name) when is_binary(name) and name != "" do
    Repo.one(
      from metric_point in MetricPoint,
        where: metric_point.project_id == ^project_id and metric_point.name == ^name,
        order_by: [desc: metric_point.timestamp, desc: metric_point.id],
        limit: 1,
        select: %{name: metric_point.name, type: metric_point.type}
    )
  end

  def latest_metric(%Project{} = project, _name), do: latest_metric(project)

  def paginate_metric_points(
        %Project{} = project,
        filters \\ %{},
        page \\ 1,
        per_page \\ @default_page_size
      ) do
    page = normalize_page(page)
    per_page = normalize_per_page(per_page, @default_page_size)

    query = filtered_metric_query(project, filters)

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = max(div(total_count + per_page - 1, per_page), 1)
    page = min(page, total_pages)
    offset = (page - 1) * per_page

    entries =
      query
      |> order_by([metric_point], desc: metric_point.timestamp, desc: metric_point.id)
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  def chart_data(%Project{} = project, filters \\ %{}) do
    filters = normalize_filters(filters)
    window = window_config(filters["window"])

    rows =
      project
      |> filtered_metric_query(filters)
      |> aggregate_chart_rows(window.bucket)
      |> Repo.all()
      |> Enum.map(&normalize_bucket/1)

    %{
      name: filters["name"],
      type: normalize_type(filters["type"]),
      unit: metric_unit(project, filters),
      buckets: rows
    }
  end

  defp aggregate_chart_rows(query, "minute") do
    query
    |> group_by([metric_point], fragment("date_trunc('minute', ?)", metric_point.timestamp))
    |> order_by([metric_point], asc: fragment("date_trunc('minute', ?)", metric_point.timestamp))
    |> select([metric_point], %{
      bucket: fragment("date_trunc('minute', ?)", metric_point.timestamp),
      sum: sum(metric_point.value),
      avg: avg(metric_point.value),
      min: min(metric_point.value),
      max: max(metric_point.value),
      count: count(metric_point.id)
    })
  end

  defp aggregate_chart_rows(query, "hour") do
    query
    |> group_by([metric_point], fragment("date_trunc('hour', ?)", metric_point.timestamp))
    |> order_by([metric_point], asc: fragment("date_trunc('hour', ?)", metric_point.timestamp))
    |> select([metric_point], %{
      bucket: fragment("date_trunc('hour', ?)", metric_point.timestamp),
      sum: sum(metric_point.value),
      avg: avg(metric_point.value),
      min: min(metric_point.value),
      max: max(metric_point.value),
      count: count(metric_point.id)
    })
  end

  defp aggregate_chart_rows(query, "day") do
    query
    |> group_by([metric_point], fragment("date_trunc('day', ?)", metric_point.timestamp))
    |> order_by([metric_point], asc: fragment("date_trunc('day', ?)", metric_point.timestamp))
    |> select([metric_point], %{
      bucket: fragment("date_trunc('day', ?)", metric_point.timestamp),
      sum: sum(metric_point.value),
      avg: avg(metric_point.value),
      min: min(metric_point.value),
      max: max(metric_point.value),
      count: count(metric_point.id)
    })
  end

  def normalize_filters(filters) when is_map(filters) do
    %{
      "name" => normalize_name(Map.get(filters, "name")),
      "type" => normalize_type_param(Map.get(filters, "type")),
      "window" => normalize_window(Map.get(filters, "window"))
    }
  end

  def retention_days do
    :argus
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:retention_days, @default_retention_days)
  end

  def prune_expired_metric_points(%Project{id: project_id}) do
    cutoff =
      DateTime.utc_now(:second)
      |> DateTime.add(-retention_days() * 86_400, :second)

    {count, _} =
      Repo.delete_all(
        from metric_point in MetricPoint,
          where: metric_point.project_id == ^project_id and metric_point.timestamp < ^cutoff
      )

    count
  end

  defp insert_row(%Project{} = project, item, now) when is_map(item) do
    with name when is_binary(name) and name != "" <- Map.get(item, "name"),
         {:ok, type} <- parse_type(Map.get(item, "type")),
         value when is_number(value) <- Map.get(item, "value") do
      %{
        project_id: project.id,
        timestamp: parse_timestamp(Map.get(item, "timestamp")) || now,
        name: name,
        type: type,
        value: value * 1.0,
        unit: normalize_optional_string(Map.get(item, "unit")),
        trace_id: normalize_optional_string(Map.get(item, "trace_id")),
        span_id: normalize_optional_string(Map.get(item, "span_id")),
        attributes: normalize_attributes(Map.get(item, "attributes")),
        raw_payload: item,
        inserted_at: now,
        updated_at: now
      }
    else
      _ -> nil
    end
  end

  defp insert_row(_project, _item, _now), do: nil

  defp filtered_metric_query(%Project{id: project_id}, filters) do
    filters = normalize_filters(filters)

    since =
      DateTime.utc_now(:second)
      |> DateTime.add(-window_config(filters["window"]).seconds, :second)

    from(metric_point in MetricPoint,
      where: metric_point.project_id == ^project_id and metric_point.timestamp >= ^since
    )
    |> maybe_filter_name(filters["name"])
    |> maybe_filter_type(filters["type"])
  end

  defp maybe_filter_name(query, nil), do: query
  defp maybe_filter_name(query, ""), do: query

  defp maybe_filter_name(query, name),
    do: where(query, [metric_point], metric_point.name == ^name)

  defp maybe_filter_type(query, nil), do: query
  defp maybe_filter_type(query, ""), do: query

  defp maybe_filter_type(query, type),
    do: where(query, [metric_point], metric_point.type == ^type)

  defp metric_unit(project, filters) do
    filters = normalize_filters(filters)

    Repo.one(
      project
      |> filtered_metric_query(filters)
      |> where([metric_point], not is_nil(metric_point.unit))
      |> order_by([metric_point], desc: metric_point.timestamp, desc: metric_point.id)
      |> limit(1)
      |> select([metric_point], metric_point.unit)
    )
  end

  defp parse_type("counter"), do: {:ok, :counter}
  defp parse_type("gauge"), do: {:ok, :gauge}
  defp parse_type("distribution"), do: {:ok, :distribution}
  defp parse_type(:counter), do: {:ok, :counter}
  defp parse_type(:gauge), do: {:ok, :gauge}
  defp parse_type(:distribution), do: {:ok, :distribution}
  defp parse_type(_), do: :error

  defp normalize_type("counter"), do: :counter
  defp normalize_type("gauge"), do: :gauge
  defp normalize_type("distribution"), do: :distribution
  defp normalize_type(:counter), do: :counter
  defp normalize_type(:gauge), do: :gauge
  defp normalize_type(:distribution), do: :distribution
  defp normalize_type(_), do: nil

  defp normalize_type_param(value) do
    case normalize_type(value) do
      nil -> ""
      type -> Atom.to_string(type)
    end
  end

  defp normalize_name(value) when is_binary(value), do: String.trim(value)
  defp normalize_name(_), do: ""

  defp normalize_window(window) when is_map_key(@windows, window), do: window
  defp normalize_window(_), do: "1h"

  defp window_config(window), do: Map.fetch!(@windows, normalize_window(window))

  defp normalize_bucket(bucket) do
    %{
      bucket: DateTime.from_naive!(bucket.bucket, "Etc/UTC"),
      sum: number_or_zero(bucket.sum),
      avg: number_or_zero(bucket.avg),
      min: number_or_zero(bucket.min),
      max: number_or_zero(bucket.max),
      count: bucket.count
    }
  end

  defp number_or_zero(nil), do: 0.0
  defp number_or_zero(%Decimal{} = value), do: Decimal.to_float(value)
  defp number_or_zero(value) when is_number(value), do: value * 1.0

  defp normalize_optional_string(value) when is_binary(value) and value != "", do: value
  defp normalize_optional_string(_), do: nil

  defp normalize_attributes(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), unwrap_attribute_value(value)} end)
  end

  defp normalize_attributes(_), do: %{}

  defp unwrap_attribute_value(%{"value" => value}), do: value
  defp unwrap_attribute_value(%{value: value}), do: value
  defp unwrap_attribute_value(value), do: value

  defp parse_timestamp(nil), do: nil
  defp parse_timestamp(%DateTime{} = value), do: DateTime.truncate(value, :second)

  defp parse_timestamp(value) when is_integer(value) do
    DateTime.from_unix!(value, :second)
  end

  defp parse_timestamp(value) when is_float(value) do
    value
    |> trunc()
    |> DateTime.from_unix!(:second)
  end

  defp parse_timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> DateTime.truncate(datetime, :second)
      _ -> nil
    end
  end

  defp parse_timestamp(_), do: nil

  defp normalize_page(page) when is_integer(page) and page > 0, do: page

  defp normalize_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp normalize_page(_page), do: 1

  defp normalize_per_page(per_page, _default) when is_integer(per_page) and per_page > 0,
    do: per_page

  defp normalize_per_page(per_page, default) when is_binary(per_page) do
    case Integer.parse(per_page) do
      {per_page, ""} when per_page > 0 -> per_page
      _ -> default
    end
  end

  defp normalize_per_page(_per_page, default), do: default
end
