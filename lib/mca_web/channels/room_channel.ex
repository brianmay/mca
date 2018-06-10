defmodule McaWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("new_msg", %{"body" => _body}, socket) do
    try do
      IO.puts("starting...")
      configs = get_configs()

      push(socket, "new_msg", %{"type" => "start"})
      Ptv.Planner.do_plan(configs, &push(socket, "new_msg", %{"type" => "leg", "leg" => &1}))
      push(socket, "new_msg", %{"type" => "finish"})
      IO.puts("done...")
    rescue
      exception ->
        stacktrace = System.stacktrace()
        push(socket, "new_msg", %{"type" => "error", "message" => inspect(exception)})
        reraise exception, stacktrace
    end

    {:noreply, socket}
  end

  @spec get_configs :: list(Ptv.Planner.Connection.t())
  def get_configs do
    direction_id = Test.get_city_direction(2)

    [
      %Ptv.Planner.Connection{
        connection_time: 0,
        # Upper Ferntree Gully Station
        depart_stop_id: 1199,
        # Train
        route_type: 0,
        # Belgrave Train line
        route_id: 2,
        search_params: [
          date_utc: Utils.parse_time("07:38:00"),
          direction_id: direction_id,
          max_results: 1
        ],
        connection_final_stop: [
          %Ptv.Planner.ConnectionFinalStop{
            arrive_stop_id: 1162,
            connections: [
              %Ptv.Planner.Connection{
                connection_time: 0,
                depart_stop_id: 1162,
                route_type: 0,
                search_params: [
                  direction_id: direction_id,
                  max_results: 10
                ],
                connection_final_stop: [
                  %Ptv.Planner.ConnectionFinalStop{
                    arrive_stop_id: 1071
                  }
                ]
              }
            ]
          },
          %Ptv.Planner.ConnectionFinalStop{
            arrive_stop_id: 1155,
            connections: [
              %Ptv.Planner.Connection{
                connection_time: 60,
                depart_stop_id: 1155,
                route_type: 0,
                search_params: [
                  platform_numbers: 3,
                  max_results: 10
                ],
                connection_final_stop: [
                  %Ptv.Planner.ConnectionFinalStop{
                    arrive_stop_id: 1071
                  }
                ]
              }
            ]
          },
          %Ptv.Planner.ConnectionFinalStop{
            arrive_stop_id: 1071
          }
        ]
      }
    ]
  end
end
