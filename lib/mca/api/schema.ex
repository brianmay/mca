defmodule Mca.API.Schema do
  use Absinthe.Schema

  alias Mca.API.UsersResolver

  object :user do
    field(:id, non_null(:id))
    field(:email, non_null(:string))
    field(:is_admin, non_null(:boolean))
  end

  input_object :update_user_params do
    field(:name, :string)
    field(:email, :string)
    field(:password, :string)
  end

  query do
    field(:all_users, list_of(non_null(:user))) do
      resolve(&UsersResolver.all_users/3)
    end
  end

  mutation do
    field :update_user, type: :user do
      arg(:id, non_null(:integer))
      arg(:user, :update_user_params)

      resolve(&UsersResolver.update/2)
    end
  end
end
