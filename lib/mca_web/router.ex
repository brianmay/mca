defmodule McaWeb.Router do
  use McaWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :auth do
    plug(Mca.Auth.Pipeline)
  end

  pipeline :ensure_auth do
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  # Maybe logged in scope
  scope "/", McaWeb do
    pipe_through([:browser, :auth])
    get("/", PageController, :index)
    post("/", PageController, :login)
    post("/logout", PageController, :logout)
  end

  # Definitely logged in scope
  scope "/", McaWeb do
    pipe_through([:browser, :auth, :ensure_auth])
    get("/connections", PageController, :authenticated)
  end

  # Other scopes may use custom stacks.
  # scope "/api", McaWeb do
  #   pipe_through :api
  # end
end
