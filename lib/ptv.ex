defmodule Ptv do
  use Tesla

  plug :sign_url
  plug Tesla.Middleware.BaseUrl, "https://timetableapi.ptv.vic.gov.au"
  plug Tesla.Middleware.Headers, %{"User-Agent" => "tesla"}
  plug Tesla.Middleware.JSON

  def get_signed_url(url, query) do
    dev_id = Application.fetch_env!(:mca, :dev_id)
    key = Application.fetch_env!(:mca, :key)

    query = Keyword.put(query, :devid, dev_id)
    url = Tesla.build_url(url, query)
    IO.puts(key)
    IO.puts(url)
    signature = :crypto.hmac(:sha, key, url)
    |> Base.encode16
    |> String.downcase

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
        200  -> { :ok, result.body }
        _    -> { :error, result.body.message }
    end
  end

  def search(search_term, query \\ []) do
    get("/v3/search/" <> search_term, query: query)
    |> check_result()
  end

  def get_directions(route_id, query \\ []) do
    get("/v3/directions/route/" <> Integer.to_string(route_id), query: query)
    |> check_result()
  end

end

