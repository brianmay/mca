defmodule McaWeb.PageController do
  use McaWeb, :controller

  alias Mca.Auth
  alias Mca.Auth.User
  alias Mca.Auth.Guardian

  def unauthenticated(conn, _params) do
    changeset = Auth.change_user(%User{})

    conn
    |> render(
      "index.html",
      changeset: changeset,
      action: page_path(conn, :login)
    )
  end

  def index(conn, params) do
    maybe_user = Guardian.Plug.current_resource(conn)

    case maybe_user do
      nil -> unauthenticated(conn, params)
      _ -> authenticated(conn, params)
    end
  end

  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    Auth.authenticate_user(email, password)
    |> login_reply(conn)
  end

  defp login_reply({:error, error}, conn) do
    conn
    |> put_flash(:error, error)
    |> redirect(to: "/")
  end

  defp login_reply({:ok, user}, conn) do
    conn
    |> put_flash(:success, "Welcome back!")
    |> Guardian.Plug.sign_in(user)
    |> redirect(to: "/")
  end

  def logout_form(conn, _params) do
    maybe_user = Guardian.Plug.current_resource(conn)

    conn
    |> render("logout.html", maybe_user: maybe_user)
  end

  def logout(conn, _) do
    conn
    |> Guardian.Plug.sign_out()
    |> redirect(to: page_path(conn, :login))
  end

  def authenticated(conn, _params) do
    render(conn, "authenticated.html")
  end
end
