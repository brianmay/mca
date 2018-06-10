use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mca, McaWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :mca, Mca.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "mca",
  password: "q1w2e3r4",
  database: "mca_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
