defmodule McaWeb.Router do
  use McaWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Mca.Auth.Pipeline)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:put_secure_browser_headers)
    plug(Mca.Auth.Pipeline)
    plug(McaWeb.Context)
  end

  pipeline :ensure_auth do
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  # Maybe logged in scope
  scope "/", McaWeb do
    pipe_through([:browser])
    get("/", PageController, :index)
    post("/", PageController, :login)
    get("/logout", PageController, :logout_form)
    post("/logout", PageController, :logout)
  end

  scope "/api" do
    pipe_through([:api])
    forward("/", Absinthe.Plug, schema: Mca.API.Schema, json_codec: Jason)
  end

  scope "/" do
    pipe_through([:api, :ensure_auth])

    forward(
      "/graphiql",
      Absinthe.Plug.GraphiQL,
      schema: Mca.API.Schema,
      interface: :simple,
      context: %{pubsub: Mca.Endpoint},
      json_codec: Jason
    )
  end

  # Definitely logged in scope
  scope "/", McaWeb do
    pipe_through([:browser, :ensure_auth])
    get("/*path", PageController, :authenticated)
  end
end
