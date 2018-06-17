import * as React from 'react'
import { graphql, QueryRenderer } from 'react-relay';
import environment from '../relay'
import UserList from './UserList'

export default class UserMeow extends React.Component<{}, {}> {
  constructor(props) {
    super(props);

    this.state = {};
  }
  render() {
    return (
      <div>
        <QueryRenderer
          environment={environment}
          query={graphql`
         query userListQuery {
           allUsers {
             id,
             ... UserList_allUsers
           }
         }
       `}
          variables={{}}
          render={({ error, props }) => {
            if (error) {
              return <div>Error!</div>;
            }
            if (!props) {
              return <div>Loading...</div>;
            }
            // return <div>User ID: {props.allUsers[0].id}</div>;
            return <UserList allUsers={props.allUsers} />
          }}
        />
      </div>
    );
  }
}
