import * as React from 'react'
import { Link, RouteComponentProps } from 'react-router-dom'
import { Table, Jumbotron, Button, Row, Col } from 'reactstrap'
import { Socket, Channel } from "phoenix"
import * as classNames from 'classnames'
import * as Immutable from 'immutable';



interface Leg {
  leg_id: string
  prev_leg_id: string
  final_leg: boolean
  depart_real_time: boolean
  arrive_real_time: boolean
  depart_dt: String
  arrive_dt: String
  first_stop_name: String
  final_stop_name: String
  first_platform: String
}

type Route = Leg[];
type LegsState = Immutable.Map<string, Leg>

interface LegProps {
  leg: Leg
}

interface RouteProps {
  route: Route
}

interface RoutesProps {
  routes: Route[]
}

interface State {
  legs: LegsState
}


function get_route_from_leg(legs : LegsState, leg : Leg) : Route {
  let list = [];
  if (leg.prev_leg_id) {
    let prev_leg = legs.get(leg.prev_leg_id)
    list = list.concat(get_route_from_leg(legs, prev_leg));
  }
  list.push(leg);
  return list;
}


function get_routes_from_legs(legs : LegsState) : Route[] {
  let routes = legs
    .valueSeq()
    .toArray()
    .filter(leg => leg.final_leg)
    .map(leg => get_route_from_leg(legs, leg))
    .sort(
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
      })

  return routes
}

class LegComponent extends React.Component<LegProps, {}> {

  public render(): JSX.Element {
    let leg = this.props.leg;
    let depart_classname = classNames({ 'realtime': leg.depart_real_time });
    let arrive_classname = classNames({ 'realtime': leg.arrive_real_time });

    return (
      <td>
        <span className={ depart_classname }>{leg.depart_dt}</span> {leg.first_stop_name} {leg.first_platform}<br />
        <span className={ arrive_classname }>{leg.arrive_dt}</span> {leg.final_stop_name}<br />
      </td>
    )
  }
}

class RouteComponent extends React.Component<RouteProps, {}> {

  public render(): JSX.Element {
    let route = this.props.route;
    return (
      <tr>
        {route.map((leg) =>
          <LegComponent key={leg.leg_id} leg={leg} />
        )}
      </tr>
    )
  }
}

class RoutesComponent extends React.Component<RoutesProps, {}> {

  public render(): JSX.Element {
    let routes = this.props.routes;
    return (
      <Table>
        <tbody>
          {routes.map((route) =>
            <RouteComponent  key={route[route.length - 1].leg_id} route={route} />
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

    this.state = {
      legs: Immutable.Map<string, Leg>(),
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
    let new_legs = this.state.legs;

    new_legs = new_legs.set(leg.leg_id, leg);

    console.log("Setting new state", new_legs)
    this.setState({
      legs: new_legs,
    })
  }

  public render(): JSX.Element {
    const routes = get_routes_from_legs(this.state.legs);
    return (
      <div>
        <Button color="primary" onClick={() => { this.reload() }}>Reload</Button>
        <RoutesComponent routes={routes} />
      </div>
    )
  }
}
