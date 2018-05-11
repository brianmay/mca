defmodule Ptv do
  use Tesla

  plug(:sign_url)
  plug(Tesla.Middleware.BaseUrl, "https://timetableapi.ptv.vic.gov.au")
  plug(Tesla.Middleware.Headers, %{"User-Agent" => "tesla"})
  plug(Tesla.Middleware.JSON)

  defp get_signed_url(url, query) do
    dev_id = Application.fetch_env!(:mca, :dev_id)
    key = Application.fetch_env!(:mca, :key)

    query = Keyword.put(query, :devid, dev_id)
    url = Tesla.build_url(url, query)

    signature =
      :crypto.hmac(:sha, key, url)
      |> Base.encode16()
      |> String.downcase()

    query = %{:signature => signature}
    Tesla.build_url(url, query)
  end

  defp apply_signed_url(env) do
    env
    |> Map.put(:url, get_signed_url(env.url, env.query))
    |> Map.put(:query, [])
  end

  def sign_url(env, next, _options \\ []) do
    env
    |> apply_signed_url()
    |> Tesla.run(next)
  end

  defp check_result(result) do
    case result.status do
      200 -> {:ok, result.body}
      400 -> {:error, "Bad Request"}
      _ -> {:error, result.body.message}
    end
  end

  defp format_datetime(datetime) do
    datetime
    |> Calendar.DateTime.shift_zone!("Etc/UTC")
    |> Calendar.DateTime.Format.iso8601()
  end

  defp format_datetime_query(query) do
    Keyword.update(query, :date_utc, nil, &format_datetime(&1))
  end

  def parse_datetime(datetime) do
    {:ok, datetime, 0} = Calendar.NaiveDateTime.Parse.iso8601(datetime)
    {:ok, datetime} = Calendar.DateTime.from_naive(datetime, "Etc/UTC")
    datetime
  end

  def search(search_term, query \\ []) do
    ("/v3/search/" <> URI.encode(search_term))
    |> get(query: query)
    |> check_result()
  end

  def get_directions(route_id, query \\ []) do
    ("/v3/directions/route/" <> Integer.to_string(route_id))
    |> get(query: query)
    |> check_result()
  end

  def get_stop(stop_id, route_type, query \\ []) do
    ("/v3/stops/" <> Integer.to_string(stop_id) <> "/route_type/" <> Integer.to_string(route_type))
    |> get(query: query)
    |> check_result()
  end

  def get_pattern(run_id, route_type, query \\ []) do
    query = format_datetime_query(query)

    ("/v3/pattern/run/" <>
       Integer.to_string(run_id) <> "/route_type/" <> Integer.to_string(route_type))
    |> get(query: query)
    |> check_result()
  end

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
