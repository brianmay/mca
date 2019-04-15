defmodule Ptv.Sign do
  @behaviour Tesla.Middleware

  @spec get_signed_url(String.t(), list()) :: String.t()
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

  @spec apply_signed_url(map) :: map
  defp apply_signed_url(env) do
    env
    |> Map.put(:url, get_signed_url(env.url, env.query))
    |> Map.put(:query, [])
  end

  @spec call(map, term, keyword) :: map
  def call(env, next, _options \\ []) do
    env
    |> apply_signed_url()
    |> Tesla.run(next)
  end
end
