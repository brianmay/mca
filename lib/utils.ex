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
end
