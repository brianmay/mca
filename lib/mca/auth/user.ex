defmodule Mca.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true)
    field(:password_hash, :string)
    field(:is_admin, :boolean)

    timestamps()
  end

  @doc false
  def changeset(%Mca.Auth.User{} = user, attrs) do
    user
    |> cast(attrs, [:email, :password, :is_admin])
    |> validate_required([:email, :is_admin])
    |> unique_constraint(:email)
    |> put_pass_hash()
  end

  def restricted_changeset(%Mca.Auth.User{} = user, attrs) do
    changeset(user, attrs)
    |> validate_inclusion(:is_admin, [false], message: "You cannot give yourself penguin rights.")
  end

  defp put_pass_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    change(changeset, Bcrypt.add_hash(password))
  end

  defp put_pass_hash(changeset), do: changeset
end
