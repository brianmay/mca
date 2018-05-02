defmodule McaWeb.PageController do
  use McaWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
