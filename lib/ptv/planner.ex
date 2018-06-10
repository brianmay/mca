defmodule Ptv.Planner do
  alias Ptv.Helpers

  defp generate_id(%{
         :route_type => route_type,
         :run_id => run_id,
         :first_stop_id => first_stop_id,
         :final_stop_id => final_stop_id
       }) do
    "#{route_type}/#{run_id}/#{first_stop_id}-#{final_stop_id}"
  end

  defmodule Leg do
    @type t :: %__MODULE__{
            leg_id: number,
            prev_leg_id: number,
            first_stop_name: String.t(),
            first_platform: String.t(),
            depart_dt: DateTime.t(),
            depart_real_time: boolean,
            final_stop_name: String.t(),
            arrive_dt: DateTime.t(),
            arrive_real_time: boolean
          }

    @enforce_keys [
      :leg_id,
      :prev_leg_id,
      :first_stop_name,
      :first_platform,
      :depart_dt,
      :depart_real_time,
      :final_stop_name,
      :arrive_dt,
      :arrive_real_time
    ]

    defstruct leg_id: nil,
              prev_leg_id: nil,
              first_stop_name: nil,
              first_platform: nil,
              depart_dt: nil,
              depart_real_time: nil,
              final_stop_name: nil,
              arrive_dt: nil,
              arrive_real_time: nil,
              is_final_leg: nil
  end

  defmodule ConnectionFinalStop do
    @type t :: %__MODULE__{
            arrive_stop_id: number,
            connections: list(Ptv.Planner.Connection.t())
          }

    @enforce_keys [
      :arrive_stop_id
    ]

    defstruct arrive_stop_id: nil,
              connections: nil
  end

  defmodule Connection do
    @type t :: %__MODULE__{
            connection_time: number,
            depart_stop_id: number,
            route_type: number,
            route_id: number,
            search_params: keyword,
            connection_final_stop: list(ConnectionFinalStop.t()),
            prev_leg_id: String.t() | nil,
            ignore_run_ids: MapSet.t()
          }

    @enforce_keys [
      :connection_time,
      :depart_stop_id,
      :route_type,
      :search_params,
      :connection_final_stop
    ]

    defstruct connection_time: nil,
              depart_stop_id: nil,
              route_type: nil,
              route_id: nil,
              search_params: nil,
              connection_final_stop: nil,
              prev_leg_id: nil,
              ignore_run_ids: MapSet.new()
  end

  @spec do_result(map, map, map, map, list, String.t(), (Leg.t() -> term), boolean) :: String.t()
  defp do_result(
         first_stop,
         final_stop,
         departure,
         run,
         pattern,
         prev_leg_id,
         callback,
         is_final_leg
       ) do
    route_type = Map.fetch!(run, "route_type")
    run_id = Map.fetch!(run, "run_id")

    first_stop_name = Map.fetch!(first_stop, "stop_name")
    final_stop_name = Map.fetch!(final_stop, "stop_name")

    first_stop_id = Map.fetch!(first_stop, "stop_id")
    final_stop_id = Map.fetch!(final_stop, "stop_id")

    # departure = Helpers.get_departure_from_pattern!(pattern, first_stop_id)
    {depart_real_time, depart_dt} = Helpers.get_departure_dt(departure)
    {arrive_real_time, arrive_dt} = Helpers.estimate_arrival_time(pattern, final_stop_id)

    first_platform = Map.fetch!(departure, "platform_number")

    leg_id =
      generate_id(%{
        route_type: route_type,
        run_id: run_id,
        first_stop_id: first_stop_id,
        final_stop_id: final_stop_id
      })

    # IO.puts("---- " <> inspect(leg_id) <> " " <> inspect(prev_leg_id))
    #
    # IO.puts(
    #   "#{first_stop_name} #{first_platform} #{Helpers.format_datetime(depart_dt)} #{
    #     depart_real_time
    #   } --> "
    # )
    #
    # IO.puts("#{final_stop_name} #{Helpers.format_datetime(arrive_dt)} #{arrive_real_time}")

    leg = %Leg{
      leg_id: leg_id,
      prev_leg_id: prev_leg_id,
      first_stop_name: first_stop_name,
      first_platform: first_platform,
      depart_dt: Utils.format_datetime(depart_dt),
      depart_real_time: depart_real_time,
      final_stop_name: final_stop_name,
      arrive_dt: Utils.format_datetime(arrive_dt),
      arrive_real_time: arrive_real_time,
      is_final_leg: is_final_leg
    }

    callback.(leg)

    leg_id
  end

  @spec do_entry_connection(
          Connection.t(),
          map,
          map,
          map,
          list,
          ConnectionFinalStop.t(),
          (Leg.t() -> term)
        ) :: nil
  defp do_entry_connection(
         entry,
         first_stop,
         departure,
         run,
         pattern,
         connection_final_stop,
         callback
       ) do
    stop_id = connection_final_stop.arrive_stop_id
    route_type = Map.fetch!(run, "route_type")
    run_id = Map.fetch!(departure, "run_id")

    {:ok, %{"stop" => final_stop}} = Ptv.get_stop(stop_id, route_type)
    {_, arrive_dt} = Helpers.estimate_arrival_time(pattern, stop_id)

    connections = connection_final_stop.connections
    is_final_leg = is_nil(connections)

    # depart_stop_id = Map.get(connection, :depart_stop_id)
    prev_leg_id = Map.get(entry, :prev_leg_id)

    leg_id =
      do_result(
        first_stop,
        final_stop,
        departure,
        run,
        pattern,
        prev_leg_id,
        callback,
        is_final_leg
      )

    connections =
      case connections do
        nil -> []
        _ -> connections
      end

    Enum.each(connections, fn connection ->
      search_params =
        Keyword.merge(
          connection.search_params,
          date_utc: arrive_dt
        )

      ignore_run_ids =
        entry.ignore_run_ids
        |> MapSet.put(run_id)

      connection = %Connection{
        connection
        | search_params: search_params,
          prev_leg_id: leg_id,
          ignore_run_ids: ignore_run_ids
      }

      do_entry(connection, callback)
    end)

    nil
  end

  @spec do_entry_departure(Connection.t(), map, map, map, list, (Leg.t() -> term)) :: nil
  defp do_entry_departure(entry, first_stop, departure, run, pattern, callback) do
    Enum.each(entry.connection_final_stop, fn connection_final_stop ->
      stop_id = connection_final_stop.arrive_stop_id
      final_departure = Helpers.get_departure_from_pattern(pattern, stop_id)

      if not is_nil(final_departure) do
        do_entry_connection(
          entry,
          first_stop,
          departure,
          run,
          pattern,
          connection_final_stop,
          callback
        )
      else
        IO.puts("Service does not stop at #{stop_id}.")
      end
    end)

    nil
  end

  @spec do_check_departure_dt(Connection.t(), map, map, map, list, (Leg.t() -> term)) :: nil
  defp do_check_departure_dt(entry, first_stop, departure, run, pattern, callback) do
    earliest_depart_dt = Keyword.fetch!(entry.search_params, :date_utc)
    {_, depart_dt} = Helpers.get_departure_dt(departure)
    run_id = Map.fetch!(departure, "run_id")

    ignore_run_ids =
      Map.get(entry, :ignore_run_ids)
      |> case do
        nil -> MapSet.new()
        value -> value
      end

    cond do
      Calendar.DateTime.before?(depart_dt, earliest_depart_dt) ->
        IO.puts("Service leaves too early.")

      MapSet.member?(ignore_run_ids, run_id) ->
        IO.puts("Service is ignored; we have already this run.")

      true ->
        do_entry_departure(entry, first_stop, departure, run, pattern, callback)
    end

    nil
  end

  @spec do_entry_departures(Connection.t(), map, list, list, (Leg.t() -> term)) :: nil
  defp do_entry_departures(entry, first_stop, departures, runs, callback) do
    Enum.each(departures, fn departure ->
      stop_id = Map.fetch!(departure, "stop_id")
      run_id = Map.fetch!(departure, "run_id")
      run = Map.fetch!(runs, Integer.to_string(run_id))
      route_type = Map.fetch!(run, "route_type")
      IO.puts("----> " <> inspect(stop_id))

      {_, depart_dt} = Helpers.get_departure_dt(departure)
      {:ok, %{"departures" => pattern}} = Ptv.get_pattern(run_id, route_type, date_utc: depart_dt)

      # The pattern sometimes has more real time information then the departure.
      departure = Helpers.get_departure_from_pattern!(pattern, stop_id)
      do_check_departure_dt(entry, first_stop, departure, run, pattern, callback)
      IO.puts("<---- " <> inspect(stop_id))
    end)

    nil
  end

  @spec do_entry(Connection.t(), (Leg.t() -> term)) :: nil
  defp do_entry(entry, callback) do
    route_type = entry.route_type
    route_id = Map.get(entry, :route_id)
    stop_id = entry.depart_stop_id

    connection_time = entry.connection_time

    query =
      entry.search_params
      |> Keyword.put(:expand, "run\nstop")
      |> Keyword.update(:date_utc, nil, &Calendar.DateTime.add!(&1, connection_time))

    IO.puts("")
    IO.puts("--------------")
    IO.puts("000" <> inspect(stop_id))

    {:ok, %{"departures" => departures, "runs" => runs, "stops" => stops}} =
      Ptv.get_departures(
        route_type,
        stop_id,
        route_id,
        query
      )

    first_stop = Map.fetch!(stops, Integer.to_string(stop_id))
    do_entry_departures(entry, first_stop, departures, runs, callback)

    nil
  end

  @spec do_plan(list(Connection.t()), (Leg.t() -> term)) :: nil
  def do_plan(connections, callback) do
    Enum.each(connections, fn entry ->
      do_entry(entry, callback)
    end)

    nil
  end
end
