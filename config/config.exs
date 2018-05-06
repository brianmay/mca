# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :mca,
  ecto_repos: [Mca.Repo],
  time_zone: "Australia/Melbourne"

# Configures the endpoint
config :mca, McaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "HHb6p6CKDZVX/yZbtsmvETN6H9FJYng2y5O2cjcZV+xposY/8gOBNhl8SkdXPwer",
  render_errors: [view: McaWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Mca.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
