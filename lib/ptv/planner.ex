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
              final_leg: nil
  end

  defp do_result(
         first_stop,
         final_stop,
         departure,
         run,
         pattern,
         prev_leg_id,
         callback,
         final_leg
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
      final_leg: final_leg
    }

    callback.(leg)

    leg_id
  end

  defp do_entry_connection(entry, first_stop, departure, run, pattern, transfer, callback) do
    stop_id = transfer.arrive_stop_id
    route_type = Map.fetch!(run, "route_type")
    run_id = Map.fetch!(departure, "run_id")

    {:ok, %{"stop" => final_stop}} = Ptv.get_stop(stop_id, route_type)
    {_, arrive_dt} = Helpers.estimate_arrival_time(pattern, stop_id)

    depart_stop_id = Map.get(transfer, :depart_stop_id)
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
        is_nil(depart_stop_id)
      )

    if not is_nil(depart_stop_id) do
      transfer_time = transfer.transfer_time

      earliest_depart_time = Calendar.DateTime.add!(arrive_dt, transfer_time)

      search_params =
        Keyword.merge(
          transfer.search_params,
          date_utc: earliest_depart_time
        )

      ignore_run_ids =
        Map.get(entry, :ignore_run_ids)
        |> case do
          nil -> MapSet.new()
          value -> value
        end
        |> MapSet.put(run_id)

      transfer =
        Map.merge(transfer, %{
          prev_leg_id: leg_id,
          depart_stop_id: depart_stop_id,
          search_params: search_params,
          ignore_run_ids: ignore_run_ids
        })

      do_entry(transfer, callback)
    end
  end

  defp do_entry_departure(entry, first_stop, departure, run, pattern, callback) do
    Enum.each(entry.transfers, fn transfer ->
      stop_id = transfer.arrive_stop_id
      final_departure = Helpers.get_departure_from_pattern(pattern, stop_id)

      # found_transfer =
      #   case next_departure do
      #     nil ->
      #       false
      #
      #     _ ->
      #       run_id = Map.fetch!(run, "run_id")
      #       next_run_id = Map.fetch!(next_departure, "run_id")
      #       run_id != next_run_id
      #   end

      if not is_nil(final_departure) do
        do_entry_connection(entry, first_stop, departure, run, pattern, transfer, callback)
      else
        IO.puts("Service does not stop at #{stop_id}.")
      end
    end)
  end

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
  end

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
  end

  defp do_entry(entry, callback) do
    route_type = entry.route_type
    route_id = Map.get(entry, :route_id)
    stop_id = entry.depart_stop_id

    query =
      entry.search_params
      |> Keyword.put(:expand, "run\nstop")

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
  end

  def do_plan(plan, callback) do
    Enum.each(plan, fn entry ->
      do_entry(entry, callback)
    end)
  end
end
