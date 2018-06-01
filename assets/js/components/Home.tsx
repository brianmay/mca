import * as React from 'react'
import { Link, RouteComponentProps } from 'react-router-dom'
import { Alert, Table, Button } from 'reactstrap'
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
  is_running: boolean
  error: string
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
      is_running: false,
      legs: Immutable.Map<string, Leg>(),
      error: null,
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
    let new_state: State = Object.assign({}, this.state)
    new_state.legs = Immutable.Map<string, Leg>()
    new_state.is_running = true
    this.setState(new_state)
  }

  process_msg(payload) {
    let type = payload.type
    let new_state: State = Object.assign({}, this.state)
    switch (type) {
      case "start":
        new_state.legs = Immutable.Map<string, Leg>()
        new_state.is_running = true
        new_state.error = null
        break

      case "finish":
        new_state.is_running = false;
        break

      case "error":
        new_state.is_running = false;
        new_state.error = payload.message
        break

      case "leg":
        let leg = payload.leg;
        new_state.legs = this.state.legs.set(leg.leg_id, leg);
        break;
    }

    this.setState(new_state)
  }

  public render(): JSX.Element {
    const routes = get_routes_from_legs(this.state.legs);
    let error: JSX.Element = null;
    if (this.state.error) {
      error = <Alert color="danger">{ this.state.error }</Alert>
    } else if (this.state.is_running) {
      error =  <Alert color="warning">Fetching results.</Alert>
    }
    let classname = classNames({ 'running': this.state.is_running });
    return (
      <div className={classname}>
        <Button color="primary" onClick={() => { this.reload() }} disabled={this.state.is_running}>Reload</Button>
        {error}
        <RoutesComponent routes={routes} />
      </div>
    )
  }
}
