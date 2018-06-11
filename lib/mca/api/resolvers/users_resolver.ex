defmodule Mca.API.UsersResolver do
  alias Mca.Auth
  alias Mca.Auth.User
  alias Mca.Repo

  defp unauthorized do
    {:error, "Not Authorized or a Penguin"}
  end

  def all_users(_root, _args, %{context: %{current_user: %{is_admin: true}}}) do
    users = Auth.list_users()
    {:ok, users}
  end

  def all_users(_root, _args, %{context: %{current_user: %{id: id}}}) do
    users = [Auth.get_user!(id)]
    {:ok, users}
  end

  def all_users(_root, _args, _info) do
    unauthorized()
  end

  def update(%{id: id, user: user_params}, %{context: %{current_user: %{is_admin: true}}}) do
    Auth.get_user!(id)
    |> User.changeset(user_params)
    |> Repo.update()
  end

  def update(%{id: id, user: user_params}, %{context: %{current_user: %{id: id}}}) do
    Auth.get_user!(id)
    |> User.changeset(user_params)
    |> Repo.update()
  end

  def update(_root, _info) do
    unauthorized()
  end
end
