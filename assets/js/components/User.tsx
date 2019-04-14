import * as React from 'react'
import { Button } from 'reactstrap'
import gql from "graphql-tag";


const update_mutation = gql`
mutation UserUpdateMutation($id: ID!, $user: UpdateUserParams) {
  updateUser(id: $id, user: $user) {
    successful
    messages {
      field
      message
    }
    result {
      id
      isAdmin
      email
    }
  }
}`;

const delete_mutation = gql`
mutation UserDeleteMutation($id: ID!) {
  deleteUser(id: $id) {
    successful
    messages {
      field
      message
    }
    result {
      id
      isAdmin
      email
    }
  }
}`;

type ErrorFields = { [id: string]: string };


interface Props {
  user: any | null;
  edit: boolean;
  onEdit: () => void;
  onEditDone: () => void;
}

interface State {
  user: any;
  error: string | null;
  error_fields: ErrorFields;
  message: string | null;
}

class UserComponent extends React.Component<Props, State> {
  constructor(props) {
    super(props);
    this.state = {
      user: {
        isAdmin: false,
        email: "",
      },
      error: null,
      error_fields: {},
      message: null,
    }
    this.onCancel = this.onCancel.bind(this);
    this.onSave = this.onSave.bind(this);
    this.onDelete = this.onDelete.bind(this);
    this.handleInputChange = this.handleInputChange.bind(this);
  }

  onCancel() {
    this.setState({ error: null, message: null });
    this.props.onEditDone();
  }

  onSave(event) {
    event.preventDefault();
    this.setState({
      error: null,
      error_fields: {},
      message: null,
    })
  }

  onDelete() {
    this.setState({
      error: null,
      error_fields: {},
      message: null,
    })
  }

  componentWillReceiveProps(nextProps: Props) {
    // Any time props.email changes, update state.
    if (nextProps.edit && !this.props.edit) {
      this.setState({
        user: {
          email: this.props.user.email,
          isAdmin: this.props.user.isAdmin,
        },
        message: null,
        error: null,
        error_fields: {},
      });
    }
    if (!nextProps.edit) {
      this.setState({
        error: null,
        message: null,
        error_fields: {},
      })
    }
  }

  handleInputChange(event) {
    const target = event.target;
    const value = target.type === 'checkbox' ? target.checked : target.value;
    const name = target.name;

    let user = Object.assign({}, this.state.user)
    user[name] = value

    this.setState({
      user: user,
    });
  }

  render() {

    const { edit } = this.props;

    let message: JSX.Element;
    if (this.state.error) {
      message = <div className="alert alert-danger">{this.state.error}</div>
    } else if (this.state.message) {
      message = <div className="alert alert-success">{this.state.message}</div>
    }

    let delete_button: JSX.Element;
    if (this.props.user) {
      delete_button = (
        <Button onClick={this.onDelete} color="danger">
          Delete
        </Button>
      )
    }

    if (edit) {
      const { email, isAdmin } = this.state.user;

      return (
        <li className="item">
          <form>
            <div className="form-row">
              <div className="col-md-1 mb-3">
                  <label htmlFor="isAdmin">Is Administrator:</label>
                  <input
                    id="isAdmin"
                    name="isAdmin"
                    type="checkbox"
                    checked={isAdmin}
                    className={"form-control " + (this.state.error_fields.isAdmin ? 'is-invalid' : '')}
                    onChange={this.handleInputChange} />
                  <div className="invalid-feedback">
                    {this.state.error_fields.isAdmin}
                  </div>
              </div>
              <div className="col-md-11 mb-3">
                  <label htmlFor="email">E-Mail:</label>
                  <input
                    id="email"
                    name="email"
                    value={email}
                    className={"form-control " + (this.state.error_fields.email ? 'is-invalid' : '')}
                    onChange={this.handleInputChange}/>
                  <div className="invalid-feedback">
                    {this.state.error_fields.email}
                  </div>
              </div>
            </div>
            <div className="form-row">
              <div className="col-md-12 mb-3">
                <Button onClick={this.onCancel} color="secondary">
                  Cancel
                </Button>
                <Button onClick={this.onSave} color="primary" type="submit">
                  Save
                </Button>
                {delete_button}
              </div>
            </div>
          </form>
          {message}
        </li>)
    }

    const { email, isAdmin } = this.props.user;
    return (
      <li className="item">
        <div>
          <input
            checked={isAdmin}
            type="checkbox"
            readOnly
          />
          <label>
            {email}
          </label>
          <Button onClick={() => this.props.onEdit()} color="primary">
            edit
          </Button>
        </div>
        {message}
      </li>
    );
  }
}

export default UserComponent;
