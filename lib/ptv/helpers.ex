defmodule Ptv.Helpers do
  @spec get_departure_dt(map) :: {boolean, DateTime.t()}
  def get_departure_dt(%{"estimated_departure_utc" => departure_time})
      when not is_nil(departure_time) do
    {true, Ptv.parse_datetime(departure_time)}
  end

  def get_departure_dt(%{"scheduled_departure_utc" => departure_time})
      when not is_nil(departure_time) do
    {false, Ptv.parse_datetime(departure_time)}
  end

  def get_departure_dt(_departure) do
    raise "No time supplied in departure details"
  end

  @spec get_departure_from_pattern(list(), number) :: map | nil
  def get_departure_from_pattern(pattern, stop_id) do
    pattern
    |> Enum.find(&(Map.fetch!(&1, "stop_id") == stop_id))
  end

  @spec get_departure_from_pattern!(list(), number) :: map
  def get_departure_from_pattern!(pattern, stop_id) do
    result = get_departure_from_pattern(pattern, stop_id)
    %{} = result
  end

  @spec get_prev_departure_from_pattern!(list(), number) :: map
  def get_prev_departure_from_pattern!(pattern, stop_id) do
    index = Enum.find_index(pattern, &(Map.fetch!(&1, "stop_id") == stop_id))

    if index <= 0 do
      raise "Cannot get stop before first stop"
    end

    if is_nil(index) do
      nil
    else
      Enum.at(pattern, index - 1)
    end
  end

  @spec get_next_departure_from_pattern!(list(), number) :: map
  def get_next_departure_from_pattern!(pattern, stop_id) do
    index = Enum.find_index(pattern, &(Map.fetch!(&1, "stop_id") == stop_id))

    if index >= length(pattern) do
      raise "Cannot get stop before first stop"
    end

    Enum.at(pattern, index + 1)
  end

  @spec estimate_arrival_time(list, number) :: {boolean, DateTime.t()}
  def estimate_arrival_time(pattern, stop_id) do
    times = %{
      # Richmond -> Flinders Street Station
      {1162, 1071} => 4 * 60,
      # Parliament -> Flinders Street Station
      {1155, 1071} => 4 * 60,
      # Flagstaff -> Flinders Street Station
      {1181, 1071} => 4 * 60
    }

    prev_stop = get_prev_departure_from_pattern!(pattern, stop_id)
    prev_stop_id = Map.fetch!(prev_stop, "stop_id")
    {real_time, datetime} = get_departure_dt(prev_stop)
    add_seconds = Map.get(times, {prev_stop_id, stop_id})

    if is_nil(add_seconds) do
      # IO.puts("#{prev_stop_id} --> #{stop_id} ---> using departure time")
      departure = get_departure_from_pattern!(pattern, stop_id)
      get_departure_dt(departure)
    else
      # IO.puts("#{prev_stop_id} --> #{stop_id} ---> adding #{datetime} + #{add_seconds}")
      {real_time, Calendar.DateTime.add!(datetime, add_seconds)}
    end
  end
end
