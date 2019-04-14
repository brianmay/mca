import * as React from 'react'
import gql from "graphql-tag";
import { Query } from "react-apollo";

import UserList from './UserList'

const allUsers = gql`
  query userListQuery {
     allUsers {
       id
       email
       isAdmin
     }
   }
`

export default class UserMeow extends React.Component<{}, {}> {
  constructor(props) {
    super(props);

    this.state = {};
  }
  render() {
    return (
      <Query query={allUsers}>
       {({ loading, error, data }) => {
         if (loading) return <p>Loading...</p>;
         if (error) return <p>Error :(</p>;
         return <UserList allUsers={data.allUsers} />
       }}
     </Query>
    );
  }
}
