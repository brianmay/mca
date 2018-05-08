defmodule Planner do
  @time_zone Application.fetch_env!(:mca, :time_zone)

  def get_city_direction(route_id) do
    {:ok, %{"directions" => directions}} = Ptv.get_directions(route_id)

    directions
    |> Enum.find(&(Map.fetch!(&1, "direction_name") == "City (Flinders Street)"))
    |> Map.fetch!("direction_id")
  end

  def get_departure(%{
        :direction_id => direction_id,
        :route_type => route_type,
        :route_id => route_id,
        :stop_id => stop_id,
        :date_utc => date_utc
      }) do
    {:ok, %{"departures" => departures, "runs" => runs}} =
      Ptv.get_departures(
        route_type,
        stop_id,
        route_id,
        direction_id: direction_id,
        date_utc: date_utc,
        max_results: 1,
        expand: "run"
      )

    [departure | _] = departures
    run_id = Map.fetch!(departure, "run_id")
    run = Map.fetch!(runs, Integer.to_string(run_id))
    {:ok, departure, run}
  end

  def format_datetime(datetime) do
    datetime
    |> Calendar.DateTime.shift_zone!(@time_zone)
    |> Calendar.DateTime.Format.iso8601()
  end

  def parse_time(time_str) do
    Calendar.DateTime.from_date_and_time_and_zone!(
      Calendar.Date.today!(@time_zone),
      Calendar.Time.Parse.iso8601!(time_str),
      @time_zone
    )
  end

  def get_stop_dt(%{"estimated_departure_utc" => departure_time})
      when not is_nil(departure_time) do
    {true, Ptv.parse_datetime(departure_time)}
  end

  def get_stop_dt(%{"scheduled_departure_utc" => departure_time})
      when not is_nil(departure_time) do
    {false, Ptv.parse_datetime(departure_time)}
  end

  def get_stop_dt(_departure) do
    raise "No time supplied in departure details"
  end

  def print_stop_details(departure, message) do
    {real_time, departure_dt} = get_stop_dt(departure)

    dt =
      departure_dt
      |> Calendar.DateTime.shift_zone!(@time_zone)
      |> Calendar.DateTime.Format.iso8601()

    IO.puts("#{message} #{Map.fetch!(departure, "stop_id")} #{real_time} #{dt}")
  end

  def get_stop_from_pattern(pattern, stop_id) do
    result =
      pattern
      |> Enum.find(&(Map.fetch!(&1, "stop_id") == stop_id))

    %{} = result
  end

  def get_prev_stop(pattern, stop_id) do
    index = Enum.find_index(pattern, &(Map.fetch!(&1, "stop_id") == stop_id))

    if index <= 0 do
      raise "Cannot get stop before first stop"
    end

    Enum.at(pattern, index - 1)
  end

  def get_next_stop(pattern, stop_id) do
    index = Enum.find_index(pattern, &(Map.fetch!(&1, "stop_id") == stop_id))

    if index >= length(pattern) do
      raise "Cannot get stop before first stop"
    end

    Enum.at(pattern, index + 1)
  end

  def estimate_arrival_time(pattern, stop_id) do
    times = %{
      # Richmond -> Flinders Street Station
      {1162, 1071} => 4 * 60,
      # Parliament -> Flinders Street Station
      {1155, 1071} => 4 * 60,
      # Flagstaff -> Flinders Street Station
      {1181, 1071} => 4 * 60
    }

    prev_stop = get_prev_stop(pattern, stop_id)
    prev_stop_id = Map.fetch!(prev_stop, "stop_id")
    {_, datetime} = get_stop_dt(prev_stop)
    add_seconds = Map.get(times, {prev_stop_id, stop_id})

    if is_nil(add_seconds) do
      raise "No entry for {prev_stop_id} to {stop_id}"
    end

    Calendar.DateTime.add!(datetime, add_seconds)
  end

  def process_change_connection_pattern(pattern) do
    # {_, stop_datetime} = get_stop_dt(stop)
    # {_, depart_datetime} = get_stop_dt(departure)

    # route_type = Map.fetch!(run, "route_type")

    # FIXME: 1071 shouldn't be hardcoded.
    destination_stop_id = 1071

    last_stop = get_stop_from_pattern(pattern, destination_stop_id)

    arrival_time = estimate_arrival_time(pattern, destination_stop_id)

    %{
      # connection: connection,
      # stop: stop,
      # run: run,
      service2_pattern: pattern,
      service2_last_stop: last_stop,
      service2_arrival_time: arrival_time
    }
  end

  def process_change_connection(arrive_dt, departure, runs, processed_runs) do
    print_stop_details(departure, "Connection")
    {_, depart_dt} = get_stop_dt(departure)

    run_id = Map.fetch!(departure, "run_id")
    run = Map.fetch!(runs, Integer.to_string(run_id))
    route_type = Map.fetch!(run, "route_type")

    cond do
      Calendar.DateTime.before?(depart_dt, arrive_dt) ->
        IO.puts("--> Connection ignored as too early.")
        {processed_runs, []}

      MapSet.member?(processed_runs, run_id) ->
        IO.puts("---> Connection ignored as we have seen run #{run_id} already.")
        {processed_runs, []}

      true ->
        IO.puts("---> Processing run #{run_id}.")
        processed_runs = MapSet.put(processed_runs, run_id)

        {:ok, %{"departures" => pattern}} =
          Ptv.get_pattern(run_id, route_type, date_utc: depart_dt)

        result =
          Map.merge(process_change_connection_pattern(pattern), %{
            service2_run: run,
            service2_first_stop: departure
          })

        {processed_runs, [result]}
    end
  end

  def process_change_connections(arrive_dt, [departure | departures], runs, processed_runs) do
    {processed_runs, head_results} =
      process_change_connection(arrive_dt, departure, runs, processed_runs)

    {processed_runs, tail_results} =
      process_change_connections(arrive_dt, departures, runs, processed_runs)

    {processed_runs, head_results ++ tail_results}
  end

  def process_change_connections(_arrive_dt, [], _runs, processed_runs) do
    {processed_runs, []}
  end

  def process_change_stop(change, service1_last_stop, processed_runs) do
    print_stop_details(service1_last_stop, "Change stop")
    {_real_time, arrive_dt} = get_stop_dt(service1_last_stop)

    route_type = change.route_type
    params = change.params
    stop_id = Map.fetch!(service1_last_stop, "stop_id")

    query =
      Keyword.merge(
        params,
        expand: "run",
        max_results: 10,
        date_utc: arrive_dt
      )

    {:ok, data} = Ptv.get_departures(route_type, stop_id, nil, query)

    process_change_connections(
      arrive_dt,
      Map.fetch!(data, "departures"),
      Map.fetch!(data, "runs"),
      processed_runs
    )
  end

  def process_change(service1_pattern, change, processed_runs) do
    stop_id = change.stop_id
    service1_last_stop = get_stop_from_pattern(service1_pattern, stop_id)

    extra_data = %{
      service1_pattern: service1_pattern,
      service1_last_stop: service1_last_stop
    }

    {processed_runs, results} =
      case service1_last_stop do
        nil -> {processed_runs, []}
        _ -> process_change_stop(change, service1_last_stop, processed_runs)
      end

    results = Enum.map(results, &Map.merge(&1, extra_data))

    {processed_runs, results}
  end

  def process_changes(service1_pattern, [change | changes], processed_runs) do
    {processed_runs, results} = process_change(service1_pattern, change, processed_runs)
    results ++ process_changes(service1_pattern, changes, processed_runs)
  end

  def process_changes(_service1_pattern, [], _processed_runs) do
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
        # direct_next_stop: 1071,
        # direct_time: 4 * 60,
        # loop_time: 14 * 60,
        params: [
          direction_id: direction_id
        ]
      },
      %{
        route_type: 0,
        stop_id: 1155,
        # direct_next_stop: 1071,
        # direct_time: 4 * 60,
        # loop_time: 10 * 60,
        params: [
          platform_numbers: 3
        ]
      }
    ]

    {:ok, service1_first_stop, _service1_run} =
      get_departure(%{
        direction_id: direction_id,
        route_type: route_type,
        route_id: route_id,
        stop_id: stop_id,
        date_utc: date_utc
      })

    {_real_time, service1_start_dt} = get_stop_dt(service1_first_stop)

    print_stop_details(service1_first_stop, "Start")

    {:ok, %{"departures" => service1_pattern}} =
      Ptv.get_pattern(
        Map.fetch!(service1_first_stop, "run_id"),
        route_type,
        date_utc: service1_start_dt
      )

    results = process_changes(service1_pattern, changes, %MapSet{})

    results =
      Enum.sort(results, fn x, y ->
        Calendar.DateTime.before?(x.service2_arrival_time, y.service2_arrival_time)
      end)

    Enum.each(results, fn result ->
      # {s1_first_real_time, s1_first_dt} = get_stop_dt(result.service1_last_stop)
      {s1_last_real_time, s1_last_dt} = get_stop_dt(result.service1_last_stop)
      {s2_first_real_time, s2_first_dt} = get_stop_dt(result.service2_first_stop)
      s2_last_dt = result.service2_arrival_time

      # stop_1 = service1_first_stop
      stop_2 = result.service2_first_stop
      platform = Map.fetch!(stop_2, "platform_number")
      stop_3 = result.service2_last_stop

      IO.puts(
        "#{Map.fetch!(stop_2, "stop_id")} " <>
          "#{format_datetime(s1_last_dt)} #{s1_last_real_time} " <>
          "#{format_datetime(s2_first_dt)} #{s2_first_real_time} " <>
          "#{platform} #{format_datetime(s2_last_dt)} #{Map.fetch!(stop_3, "stop_id")}"
      )
    end)
  end
end
