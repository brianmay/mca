defmodule Test do
  def get_city_direction(route_id) do
    {:ok, %{"directions" => directions}} = Ptv.get_directions(route_id)

    directions
    |> Enum.find(&(Map.fetch!(&1, "direction_name") == "City (Flinders Street)"))
    |> Map.fetch!("direction_id")
  end

  def show_leg(leg) do
    IO.puts(inspect(leg))
  end

  def do_test do
    direction_id = get_city_direction(2)

    plan = [
      %{
        # Upper Ferntree Gully Station
        depart_stop_id: 1199,
        # Train
        route_type: 0,
        # Belgrave Train line
        route_id: 2,
        search_params: [
          date_utc: Utils.parse_time("07:55:00"),
          direction_id: direction_id,
          max_results: 1
        ],
        transfers: [
          %{
            arrive_stop_id: 1162,
            transfer_time: 30,
            depart_stop_id: 1162,
            route_type: 0,
            search_params: [
              direction_id: direction_id,
              max_results: 10
            ],
            transfers: [
              %{
                arrive_stop_id: 1071
              }
            ]
          },
          %{
            arrive_stop_id: 1155,
            transfer_time: 30,
            depart_stop_id: 1155,
            route_type: 0,
            search_params: [
              platform_numbers: 3,
              max_results: 10
            ],
            transfers: [
              %{
                arrive_stop_id: 1071
              }
            ]
          },
          %{
            arrive_stop_id: 1071
          }
        ]
      }
    ]

    Ptv.Planner.do_plan(plan, &show_leg/1)
  end
end
