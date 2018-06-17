defmodule Mca.API.UsersResolver do
  alias Mca.Auth
  alias Mca.Auth.User
  alias Mca.Repo

  defp unauthorized do
    {:error, "You are not an Authorized Penguin"}
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
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, %Ecto.Changeset{} = changeset} -> {:ok, changeset}
    end
  end

  def update(%{id: id, user: user_params}, %{context: %{current_user: %{id: current_id}}}) do
    case id == Integer.to_string(current_id) do
      true ->
        Auth.get_user!(id)
        |> User.restricted_changeset(user_params)
        |> Repo.update()
        |> case do
          {:ok, user} -> {:ok, user}
          {:error, %Ecto.Changeset{} = changeset} -> {:ok, changeset}
        end

      false ->
        unauthorized()
    end
  end

  def update(_root, _info) do
    unauthorized()
  end

  def add(%{user: user_params}, %{context: %{current_user: %{is_admin: true}}}) do
    %User{}
    |> User.changeset(user_params)
    |> Repo.insert()
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, %Ecto.Changeset{} = changeset} -> {:ok, changeset}
    end
  end

  def add(_root, _info) do
    unauthorized()
  end

  def delete(%{id: id}, %{context: %{current_user: %{is_admin: true, id: current_id}}}) do
    case id == Integer.to_string(current_id) do
      true ->
        {:error, "You cannot delete yourself"}

      false ->
        Auth.get_user!(id)
        |> Repo.delete()
    end
  end

  def delete(_root, _info) do
    unauthorized()
  end
end
