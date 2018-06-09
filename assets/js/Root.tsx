import * as React from 'react'
import NavBar from './components/navbar'
import { Container } from 'reactstrap'

export default class Root extends React.Component<{}, {}> {
  public render(): JSX.Element {
    return (
      <div>
        <NavBar/>
        <div className="content">
          {this.props.children}
        </div>
      </div>
    )
  }
}
