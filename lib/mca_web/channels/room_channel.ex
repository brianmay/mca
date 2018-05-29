defmodule McaWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("new_msg", %{"body" => _body}, socket) do
    # broadcast!(socket, "new_msg", %{body: "Please wait again...."})

    IO.puts("starting...")
    plan = get_plan()
    Ptv.Planner.do_plan(plan, &push(socket, "new_msg", %{"body" => &1}))
    IO.puts("done...")

    {:noreply, socket}
  end

  def get_plan do
    direction_id = Test.get_city_direction(2)

    [
      %{
        # Upper Ferntree Gully Station
        depart_stop_id: 1199,
        # Train
        route_type: 0,
        # Belgrave Train line
        route_id: 2,
        search_params: [
          date_utc: Utils.parse_time("07:53:00"),
          direction_id: direction_id,
          max_results: 1
        ],
        transfers: [
          %{
            arrive_stop_id: 1162,
            transfer_time: 0,
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
            transfer_time: 60,
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
  end
end
