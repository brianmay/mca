defmodule Mca.API.Schema do
  use Absinthe.Schema
  import Kronky.Payload
  import_types(Kronky.ValidationMessageTypes)

  alias Mca.API.UsersResolver

  object :user do
    field(:id, non_null(:id))
    field(:email, non_null(:string))
    field(:is_admin, non_null(:boolean))
  end

  input_object :update_user_params do
    field(:email, :string)
    field(:is_admin, :boolean)
    field(:password, :string)
  end

  query do
    field(:all_users, list_of(non_null(:user))) do
      resolve(&UsersResolver.all_users/3)
    end
  end

  payload_object(:user_payload, :user)

  mutation do
    field :update_user, type: :user_payload do
      arg(:id, non_null(:id))
      arg(:user, :update_user_params)

      resolve(&UsersResolver.update/2)
      middleware(&build_payload/2)
    end

    field :add_user, type: :user_payload do
      arg(:user, :update_user_params)

      resolve(&UsersResolver.add/2)
      middleware(&build_payload/2)
    end

    field :delete_user, type: :user_payload do
      arg(:id, non_null(:id))
      resolve(&UsersResolver.delete/2)
      middleware(&build_payload/2)
    end
  end
end
