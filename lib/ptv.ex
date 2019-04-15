defmodule Ptv do
  use Tesla

  plug(Ptv.Sign)
  plug(Tesla.Middleware.BaseUrl, "https://timetableapi.ptv.vic.gov.au")
  plug(Tesla.Middleware.Headers, ["User-Agent": "tesla"])
  plug(Tesla.Middleware.JSON)


  @spec check_result(map) :: {:error, String.t()} | {:ok, map}
  defp check_result({:ok, result}) do
    case result.status do
      200 ->
        {:ok, result.body}

      400 ->
        {:error, "Bad Request"}

      500 ->
        IO.puts("The PTV server generated a 500 error. " <> inspect(result))
        {:error, Map.get(result.body, "Message")}

      _ ->
        IO.puts("The PTV server generated an unknown error. " <> inspect(result))
        {:error, Map.get(result.body, "Message")}
    end
  end

  defp check_result({:error, _}=error), do: error

  @spec format_datetime(DateTime.t()) :: String.t()
  defp format_datetime(datetime) do
    datetime
    |> Calendar.DateTime.shift_zone!("Etc/UTC")
    |> Calendar.DateTime.Format.iso8601()
  end

  @spec format_datetime_query(keyword) :: keyword
  defp format_datetime_query(query) do
    Keyword.update(query, :date_utc, nil, &format_datetime(&1))
  end

  @spec parse_datetime(String.t()) :: DateTime.t()
  def parse_datetime(datetime) do
    {:ok, datetime, 0} = Calendar.NaiveDateTime.Parse.iso8601(datetime)
    {:ok, datetime} = Calendar.DateTime.from_naive(datetime, "Etc/UTC")
    datetime
  end

  @spec search(String.t(), keyword) :: {:error, String.t()} | {:ok, map}
  def search(search_term, query \\ []) do
    ("/v3/search/" <> URI.encode(search_term))
    |> get(query: query)
    |> check_result()
  end

  @spec get_directions(number, keyword) :: {:error, String.t()} | {:ok, map}
  def get_directions(route_id, query \\ []) do
    ("/v3/directions/route/" <> Integer.to_string(route_id))
    |> get(query: query)
    |> check_result()
  end

  @spec get_stop(number, number, keyword) :: {:error, String.t()} | {:ok, map}
  def get_stop(stop_id, route_type, query \\ []) do
    ("/v3/stops/" <> Integer.to_string(stop_id) <> "/route_type/" <> Integer.to_string(route_type))
    |> get(query: query)
    |> check_result()
  end

  @spec get_pattern(number, number, keyword) :: {:error, String.t()} | {:ok, map}
  def get_pattern(run_id, route_type, query \\ []) do
    query = format_datetime_query(query)

    ("/v3/pattern/run/" <>
       Integer.to_string(run_id) <> "/route_type/" <> Integer.to_string(route_type))
    |> get(query: query)
    |> check_result()
  end

  @spec get_departures(number, number, number | nil, keyword) :: {:error, String.t()} | {:ok, map}
  def get_departures(route_type, stop_id, route_id \\ nil, query \\ []) do
    query = format_datetime_query(query)

    url =
      "/v3/departures/route_type/" <>
        Integer.to_string(route_type) <> "/stop/" <> Integer.to_string(stop_id)

    case route_id do
      nil -> url
      id -> url <> "/route/" <> Integer.to_string(id)
    end
    |> get(query: query)
    |> check_result()
  end
end
