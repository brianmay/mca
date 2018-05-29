import * as React from 'react'
import { Link, RouteComponentProps } from 'react-router-dom'
import { Table, Jumbotron, Button, Row, Col } from 'reactstrap'
import { Socket, Channel } from "phoenix"
import * as classNames from 'classnames'

function get_route_from_leg(legs, leg) {
  let list = [];
  if (leg.prev_leg_id) {
    let prev_leg = legs[leg.prev_leg_id]
    list = list.concat(get_route_from_leg(legs, prev_leg));
  }
  list.push(leg);
  return list;
}


interface LegProps {
  leg: any
}

interface RouteProps {
  route: any
}

interface RoutesProps {
  routes: any[]
}



interface State {
  legs: any
  routes: any[]
}


class Leg extends React.Component<LegProps, {}> {

  public render(): JSX.Element {
    let leg = this.props.leg;
    let depart_classname = classNames({ 'real-time': leg.depart_real_time });
    let arrive_classname = classNames({ 'real-time': leg.arrive_real_time });

    return (
      <td>
        <span className={ depart_classname }>{leg.depart_dt}</span> {leg.first_stop_name} {leg.first_platform}<br />
        <span className={ arrive_classname }>{leg.arrive_dt}</span> {leg.final_stop_name}<br />
      </td>
    )
  }
}

class Route extends React.Component<RouteProps, {}> {

  public render(): JSX.Element {
    let route = this.props.route;
    return (
      <tr>
        {route.map((leg) =>
          <Leg key={leg.leg_id} leg={leg} />
        )}
      </tr>
    )
  }
}

class Routes extends React.Component<RoutesProps, {}> {

  public render(): JSX.Element {
    let routes = this.props.routes;
    return (
      <Table>
        <tbody>
          {routes.map((route) =>
            <Route  key={route[route.length - 1].leg_id} route={route} />
          )}
        </tbody>
      </Table>
    )
  }
}


export default class Home extends React.Component<{}, State> {
  channel: Channel;

  constructor(props) {
    super(props)

    console.log("I am here!!!!!!")

    this.state = {
      legs: {},
      routes: [],
    }

    const socket = new Socket("/socket")
    socket.connect()
    const channel = socket.channel("room:lobby", {})

    channel.on("new_msg", this.process_msg.bind(this))

    channel.join()
      .receive("ok", resp => {
        console.log("Joined successfully", resp)
      })
      .receive("error", resp => { console.log("Unable to join", resp) })

    this.channel = channel;
  }

  reload() {
    this.channel.push("new_msg", { body: "Penguins are evil." })
  }

  process_msg(payload) {
    let leg = payload.body;
    let new_legs = Object.assign({}, this.state.legs);
    let new_routes = Object.assign([], this.state.routes);

    new_legs[leg.leg_id] = leg;

    if (leg.final_leg) {
      let route = get_route_from_leg(new_legs, leg)
      new_routes.push(route)

      new_routes.sort(
        function(x, y) {
          let a = x.slice(-1)[0];
          let b = y.slice(-1)[0];
          let result;
          if (!a || !b) {
            result = 0;
          }
          else if (a.arrive_dt > b.arrive_dt) {
            result = 1;
          }
          else if (a.arrive_dt < b.arrive_dt) {
            result = -1;
          }
          else {
            result = 0;
          }
          return result;
        }
      )
    }

    console.log("Setting new state", new_legs, new_routes)
    this.setState({
      legs: new_legs,
      routes: new_routes,
    })
  }

  public render(): JSX.Element {
    return (
      <div>
        <Button color="primary" onClick={() => { this.reload() }}>Reload</Button>
        <Routes routes={this.state.routes} />
      </div>
    )
  }
}
