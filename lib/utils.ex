defmodule Utils do
  @time_zone Application.fetch_env!(:mca, :time_zone)

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

  def get_departure_from_pattern(pattern, stop_id) do
    result =
      pattern
      |> Enum.find(&(Map.fetch!(&1, "stop_id") == stop_id))

    %{} = result
  end

  def get_prev_departure_from_pattern(pattern, stop_id) do
    index = Enum.find_index(pattern, &(Map.fetch!(&1, "stop_id") == stop_id))

    if index <= 0 do
      raise "Cannot get stop before first stop"
    end

    Enum.at(pattern, index - 1)
  end

  def get_next_departure_from_pattern(pattern, stop_id) do
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

    prev_stop = get_prev_departure_from_pattern(pattern, stop_id)
    prev_stop_id = Map.fetch!(prev_stop, "stop_id")
    {real_time, datetime} = get_departure_dt(prev_stop)
    add_seconds = Map.get(times, {prev_stop_id, stop_id})

    if is_nil(add_seconds) do
      departure = get_departure_from_pattern(pattern, stop_id)
      get_departure_dt(departure)
    else
      {real_time, Calendar.DateTime.add!(datetime, add_seconds)}
    end
  end
end
