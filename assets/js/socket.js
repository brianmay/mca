// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket
// and connect at the socket path in "lib/web/endpoint.ex":
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/web/templates/layout/app.html.eex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/2" function
// in "lib/web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, pass the token on connect as below. Or remove it
// from connect if you don't care about authentication.

socket.connect()

let channel           = socket.channel("room:lobby", {})
let chatInput         = document.querySelector("#chat-input")
let messagesContainer = document.querySelector("#messages")

chatInput.addEventListener("keypress", event => {
      if(event.keyCode === 13){
              channel.push("new_msg", {body: chatInput.value})
              chatInput.value = ""
            }
})

function display_leg(leg) {
    let text = "";
    let depart_class="";
    if (leg.depart_real_time) {
        depart_class="realtime"
    }
    let arrive_class="";
    if (leg.arrive_real_time) {
        arrive_class="realtime"
    }
    text += `<div class="${depart_class}">` + leg.depart_dt + "</div> " + " " + leg.first_stop_name + " " + leg.first_platform + "<br/>\n";
    text += `<div class="${arrive_class}">` + leg.arrive_dt + "</div> " + " " + leg.final_stop_name + "<br/>\n"
    return text;
}

function display_route(route) {
    let td_nodes = [];
    for (let i = 0; i < route.length; i++) {
        let leg = route[i]
        let text = display_leg(leg);

        let td_node = document.createElement("td");
        td_node.innerHTML = text;
        td_nodes.push(td_node);
    }
    return td_nodes;
}

function display_routes(routes) {
    messagesContainer.innerHTML = "";
    let table = document.createElement("table");
    table.setAttribute("border", "1");
    messagesContainer.appendChild(table);

    for (let i = 0; i < routes.length; i++) {
        let route = routes[i]
        let td_nodes = display_route(route);

        let tr_node = document.createElement("tr");
        table.appendChild(tr_node);
        for (let j = 0; j < td_nodes.length; j++) {
            tr_node.appendChild(td_nodes[j]);
        }
    }
}

function get_route_from_leg(legs, leg) {
    let list = [];
    if (leg.prev_leg_id) {
        let prev_leg = legs[leg.prev_leg_id]
        list = list.concat(get_route_from_leg(legs, prev_leg));
    }
    list.push(leg);
    return list;
}


let legs = {};
let routes = [];


channel.on("new_msg", payload => {
      let leg = payload.body;
      legs[leg.leg_id] = leg;

      if (leg.final_leg) {
          let route = get_route_from_leg(legs, leg)
          routes.push(route)

          routes.sort(
              function(x, y) {
                  let a=x.slice(-1)[0];
                  let b=y.slice(-1)[0];
                  let result;
                  if (!a || !b) {
                      result=0;
                  }
                  else if (a.arrive_dt>b.arrive_dt) {
                      result = 1;
                  }
                  else if (a.arrive_dt<b.arrive_dt) {
                      result = -1;
                  }
                  else {
                      result = 0;
                  }
                  return result;
              }
          );

          display_routes(routes)
      }
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
