defmodule Planner do
  @time_zone Application.fetch_env!(:mca, :time_zone)

  def get_city_direction(route_id) do
    {:ok, %{"directions" => directions}} = Ptv.get_directions(route_id)

    directions
    |> Enum.find(&(Map.get(&1, "direction_name") == "City (Flinders Street)"))
    |> Map.get("direction_id")
  end

  def get_departure(%{
        :direction_id => direction_id,
        :route_type => route_type,
        :route_id => route_id,
        :stop_id => stop_id,
        :date_utc => date_utc
      }) do
    query = [
      direction_id: direction_id,
      date_utc: date_utc,
      max_results: 1
    ]

    {:ok, %{"departures" => departures}} =
      Ptv.get_departures(route_type, stop_id, route_id, query)

    [departure | _] = departures
    {:ok, departure}
  end

  def parse_time(time_str) do
    Calendar.DateTime.from_date_and_time_and_zone!(
      Calendar.Date.today!(@time_zone),
      Calendar.Time.Parse.iso8601!(time_str),
      @time_zone
    )
  end

  def get_departure_details(%{"estimated_departure_utc" => departure_time})
      when not is_nil(departure_time) do
    {true, Ptv.parse_datetime(departure_time)}
  end

  def get_departure_details(%{"scheduled_departure_utc" => departure_time})
      when not is_nil(departure_time) do
    {false, Ptv.parse_datetime(departure_time)}
  end

  def get_departure_details(_departure) do
    raise "No time supplied in departure details"
  end

  def print_departure_details(departure, message) do
    {real_time, departure_dt} = get_departure_details(departure)

    dt =
      departure_dt
      |> Calendar.DateTime.shift_zone!(@time_zone)
      |> Calendar.DateTime.Format.iso8601()

    IO.puts("#{message} #{departure["stop_id"]} #{real_time} #{dt}")
  end

  def get_stop_from_pattern(pattern, stop_id) do
    pattern
    |> Enum.find(&(Map.get(&1, "stop_id") == stop_id))
  end

  def process_change_connection_unique_run(change, stop, connection, runs) do
    print_departure_details(connection, "Connection")

    {_, stop_datetime} = get_departure_details(stop)
    {_, depart_datetime} = get_departure_details(connection)

    run_id = connection["run_id"]

    run = runs[Integer.to_string(run_id)]
    route_type = run["route_type"]

    if Calendar.DateTime.after?(depart_datetime, stop_datetime) do
      {:ok, %{"departures" => pattern}} =
        Ptv.get_pattern(run_id, route_type, date_utc: depart_datetime)

      IO.puts(inspect(pattern))

      # FIXME: 1071 shouldn't be hardcoded.
      destination =
        pattern
        |> Enum.find(&(Map.get(&1, "stop_id") == 1071))

      # Something went wrong if destination isn't in stopping pattern.
      %{} = destination

      stops = Enum.map(pattern, & &1["stop_id"])
      IO.puts(inspect(stops))
      direct_sequence = change[:direct_sequence]
      IO.puts(inspect(direct_sequence))
      [:ok]
    else
      []
    end
  end

  def process_change_connection(change, stop, connection, runs, processed_runs) do
    run_id = connection["run_id"]

    if not MapSet.member?(processed_runs, run_id) do
      processed_runs = MapSet.put(processed_runs, run_id)
      {processed_runs, process_change_connection_unique_run(change, stop, connection, runs)}
    else
      {processed_runs, []}
    end
  end

  def process_change_connections(change, stop, [connection | connections], runs, processed_runs) do
    {processed_runs, head_results} =
      process_change_connection(change, stop, connection, runs, processed_runs)

    {processed_runs, tail_results} =
      process_change_connections(change, stop, connections, runs, processed_runs)

    {processed_runs, head_results ++ tail_results}
  end

  def process_change_connections(_change, _stop, [], _runs, processed_runs) do
    {processed_runs, []}
  end

  def process_change_stop(change, stop, processed_runs) do
    print_departure_details(stop, "Change stop")
    {_real_time, departure_dt} = get_departure_details(stop)

    route_type = change[:route_type]
    params = change[:params]
    stop_id = stop["stop_id"]

    query =
      Keyword.merge(
        params,
        expand: "run",
        max_results: 10,
        date_utc: departure_dt
      )

    {:ok, data} = Ptv.get_departures(route_type, stop_id, nil, query)

    process_change_connections(change, stop, data["departures"], data["runs"], processed_runs)
  end

  def process_change(pattern, change, processed_runs) do
    stop_id = change[:stop_id]

    stop = get_stop_from_pattern(pattern, stop_id)

    case stop do
      nil -> []
      _ -> process_change_stop(change, stop, processed_runs)
    end
  end

  def process_changes(pattern, [change | changes], processed_runs) do
    {processed_runs, results} = process_change(pattern, change, processed_runs)
    results ++ process_changes(pattern, changes, processed_runs)
  end

  def process_changes(_pattern, [], _processed_runs) do
    []
  end

  def get_connections() do
    # Train
    route_type = 0
    # Belgrave Train line
    route_id = 2
    # Upper Ferntree Gully Station
    stop_id = 1199
    date_utc = parse_time("07:47:00")

    direction_id = get_city_direction(route_id)

    changes = [
      %{
        route_type: 0,
        stop_id: 1162,
        direct_sequence: [1162, 1071],
        direct_time: 4 * 60,
        loop_time: 14 * 60,
        params: [
          direction_id: direction_id
        ]
      },
      %{
        route_type: 0,
        stop_id: 1155,
        direct_sequence: [1155, 1071],
        direct_time: 4 * 60,
        loop_time: 10 * 60,
        params: [
          platform_numbers: 3
        ]
      }
    ]

    {:ok, departure} =
      get_departure(%{
        direction_id: direction_id,
        route_type: route_type,
        route_id: route_id,
        stop_id: stop_id,
        date_utc: date_utc
      })

    {_real_time, departure_dt} = get_departure_details(departure)

    print_departure_details(departure, "Start")

    {:ok, %{"departures" => pattern}} =
      Ptv.get_pattern(departure["run_id"], route_type, date_utc: departure_dt)

    process_changes(pattern, changes, %MapSet{})
  end
end
