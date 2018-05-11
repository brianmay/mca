defmodule Ptv.Planner do
  alias Ptv.Utils

  def do_result(first_stop, final_stop, departure, _run, pattern, prev_leg_id) do
    run_id = Map.fetch!(departure, "run_id")

    first_stop_name = Map.fetch!(first_stop, "stop_name")
    final_stop_name = Map.fetch!(final_stop, "stop_name")

    # first_stop_id = Map.fetch!(first_stop, "stop_id")
    final_stop_id = Map.fetch!(final_stop, "stop_id")

    # departure = Utils.get_departure_from_pattern(pattern, first_stop_id)
    {depart_real_time, depart_dt} = Utils.get_departure_dt(departure)
    {arrive_real_time, arrive_dt} = Utils.estimate_arrival_time(pattern, final_stop_id)

    first_platform = Map.fetch!(departure, "platform_number")

    leg_id = {run_id, final_stop_id}
    IO.puts("---- " <> inspect(leg_id) <> " " <> inspect(prev_leg_id))

    IO.puts(
      "#{first_stop_name} #{first_platform} #{Utils.format_datetime(depart_dt)} #{
        depart_real_time
      } --> "
    )

    IO.puts("#{final_stop_name} #{Utils.format_datetime(arrive_dt)} #{arrive_real_time}")

    leg_id
  end

  def do_entry_departure(entry, first_stop, departure, run, pattern) do
    prev_leg_id = Map.get(entry, :prev_leg_id)

    Enum.each(entry.transfers, fn transfer ->
      stop_id = transfer.arrive_stop_id

      route_type = Map.fetch!(run, "route_type")
      {:ok, %{"stop" => final_stop}} = Ptv.get_stop(stop_id, route_type)
      {_, arrive_dt} = Utils.estimate_arrival_time(pattern, stop_id)
      leg_id = do_result(first_stop, final_stop, departure, run, pattern, prev_leg_id)

      depart_stop_id = Map.get(transfer, :depart_stop_id)

      if not is_nil(depart_stop_id) do
        transfer_time = transfer.transfer_time

        earliest_depart_time = Calendar.DateTime.add!(arrive_dt, transfer_time)

        search_params =
          Keyword.merge(
            transfer.search_params,
            date_utc: earliest_depart_time
          )

        transfer =
          Map.merge(transfer, %{
            prev_leg_id: leg_id,
            depart_stop_id: depart_stop_id,
            search_params: search_params
          })

        do_entry(transfer)
      end
    end)
  end

  def do_check_departure_dt(entry, first_stop, departure, run, pattern) do
    earliest_depart_dt = Keyword.fetch!(entry.search_params, :date_utc)
    {_, depart_dt} = Utils.get_departure_dt(departure)

    if Calendar.DateTime.after?(depart_dt, earliest_depart_dt) do
      do_entry_departure(entry, first_stop, departure, run, pattern)
    end
  end

  def do_entry_departures(entry, first_stop, departures, runs) do
    Enum.each(departures, fn departure ->
      run_id = Map.fetch!(departure, "run_id")
      run = Map.fetch!(runs, Integer.to_string(run_id))
      route_type = Map.fetch!(run, "route_type")

      {_, depart_dt} = Utils.get_departure_dt(departure)
      {:ok, %{"departures" => pattern}} = Ptv.get_pattern(run_id, route_type, date_utc: depart_dt)
      do_check_departure_dt(entry, first_stop, departure, run, pattern)
    end)
  end

  def do_entry(entry) do
    route_type = entry.route_type
    route_id = Map.get(entry, :route_id)
    stop_id = entry.depart_stop_id

    query =
      entry.search_params
      |> Keyword.put(:expand, "run\nstop")

    {:ok, %{"departures" => departures, "runs" => runs, "stops" => stops}} =
      Ptv.get_departures(
        route_type,
        stop_id,
        route_id,
        query
      )

    first_stop = Map.fetch!(stops, Integer.to_string(stop_id))
    do_entry_departures(entry, first_stop, departures, runs)
  end

  def do_plan(plan) do
    Enum.each(plan, fn entry ->
      do_entry(entry)
    end)
  end
end
