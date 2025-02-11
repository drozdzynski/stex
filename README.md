# Storex

![Elixir CI](https://github.com/nerdslabs/storex/workflows/Elixir%20CI/badge.svg) [![Downloads](https://img.shields.io/hexpm/dt/storex.svg)](https://hex.pm/packages/storex)

Storex is a frontend store with state management handled on the backend. It allows you to update the store state both from the frontend and backend, with all communication occurring over WebSocket.

Important: Storex is currently under active development. We encourage you to report any issues or submit feature requests [here](https://github.com/nerdslabs/storex/issues/new).

## Why Storex?

### Features

- Efficient state management: Only the differences (diffs) in the store state are sent with each mutation, minimizing data transfer.
- Real-time updates: State changes are immediately reflected across all connected clients via WebSocket communication.
- Backend-driven state: Storex allows both the frontend and backend to update the store state seamlessly.
- Lightweight and fast: Designed for minimal overhead, ensuring rapid state updates and communication.

### Key Differences from Phoenix LiveView

Phoenix LiveView is a powerful tool for building rich, interactive web applications without writing custom JavaScript. However, as your application grows, managing complex client-side state across multiple LiveViews or components can become challenging. This is where Storex comes in.

- Client-Side State Management: While Phoenix LiveView handles server-side rendering and event handling, Storex focuses on managing state on the client side. It allows you to keep your client-side state in sync with the server, but with more flexibility in how that state is stored, updated, and accessed.
- Decoupled State Logic: Storex decouples state management from the LiveView itself, enabling you to manage state across multiple components or even across the entire application. This contrasts with LiveView, where state is typically tied to a specific LiveView process.
- Predictable State Updates: Storex follows a predictable, unidirectional data flow similar to Redux. This makes it easier to reason about state changes and debug issues, especially in complex applications.
- Extensibility: Storex is designed to be highly extensible, allowing you to integrate it with other tools and libraries in the Elixir ecosystem. You can also define custom middleware to handle side effects, logging, or other tasks.

For an overview of Storex in action, check out the example provided [here](https://storex-phoenix-ssr-spring-sky-1412.fly.dev/).

## Basic usage

### Installation

Add **storex** to deps in `mix.exs`:

```elixir
defp deps do
  [{:storex, "~> 0.6"}]
end
```

Also you need to add **storex** to `package.json` dependencies:

```javascript
{
  "storex": "file:../deps/storex",
}
```

### Add storex websocket handler

You need to add handler `Storex.Handler.Plug` or `Storex.Handler.Cowboy`.

**Phoenix:**
```elixir
defmodule YourAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :your_app

  plug Storex.Plug, path: "/storex"

  # ...
end
```

**Cowboy:**
```elixir
:cowboy_router.compile([
  {:_, [
    # ...
    {"/storex", Storex.Handler.Cowboy, []},
    # ...
  ]}
])
```

> [!IMPORTANT]
> Cowboy doesn't support the Node.js (HTTP Only) connector

### Create store

To create a store you need to create new elixir module with `init/2` which is called when a page is loaded, every time websocket is connected it generates session_id and passes it as the first argument, params are from Javascript store declaration. `init/2` callback need to return one of this tuples:

- `{:ok, state}` - for initial state
- `{:ok, state, key}` - for initial state with `key` which can be used as selector for future mutations
- `{:error, reason}` - to send error message to frontend on initialization

Next, you can declare `mutation/5` where the first argument is mutation name, second is data passed to mutation, next two params are same like in `init/2`, the last one is the current state of the store.

```elixir
defmodule ExampleApp.Store.Counter do
  use Storex.Store

  def init(session_id, _params) do
    {:ok, 0}
  end

  # Params have binary keys and result of `init/2` function can return `key` which will be the key for mutations.
  # def init(session_id, %{"someKey" => someKeyValue}) do
  #   {:ok, 0, someKeyValue}
  # end

  # `increase` is mutation name, `data` is payload from front-end, `session_id` is current session id of connecton, `initial_params` with which store was initialized, `state` is store current state.
  def mutation("increase", _data, _session_id, _initial_params, state) do
    state = state + 1

    {:noreply, state}
  end

  def mutation("decrease", _data, _session_id, _initial_params, state) do
    state = state - 1

    {:reply, "message", state}
  end

  def mutation("set", [number], _session_id, _initial_params, state) do
    {:noreply, number}
  end
end
```

### Connect to store

You have to connect the newly created store with a frontend side to be able to synchronise the state: `params` are passed as second argument in store `init/2` and as third in `mutation/5`. You can subscribe to changes inside store state by passing option `subscribe` with function as a value.

```typescript
import useStorex from 'storex'

const store = useStorex({
  store: 'ExampleApp.Store.Counter',
  params: {}
})
```

### Mutate store

You can mutate store from javascript with store instance:

```typescript
store.commit("increase")
store.commit("decrease").then((response) => {
  response // Reply from elixir
})
store.commit("set", 10)
```

Or directly from elixir:

```elixir
Storex.mutate(store, "increase", [])
Storex.mutate(store, "set", [10])
Storex.mutate(key, store, "increase", [])
Storex.mutate(key, store, "set", [10])
```

### Subscribe to store changes

You can subscribe to store state changes in javascript with function subscribe:

```typescript
store.subscribe((state) => {
  const state = state
})
```

You can also subscribe to events after store is created:

```typescript
store.onConnected(() => {
  console.log('connected')
})

store.onError((error) => {
  console.log('error', error)
})

store.onDisconnected((closeEvent) => {
  console.log('disconnected', closeEvent)
})
```

## Connectors
The default export of `useStorex` uses WebSocket connections only, you can extend it by using custom connector.

### Websocket

```typescript
import { prepare, socketConnector } from 'storex';

const connector = socketConnector({ address: 'wss://myapi.com/storex' });
const { useStorex } = prepare({ /* global params */ }, connector);

const myStore = useStorex<MyStateType>({
  store: 'myStoreName',
  params: { /* store-specific params */ }
});
```

### Node.js (HTTP Only)

**Node.js connector require Node.js installed on server which running application**

```typescript
import { prepare, httpConnector } from 'storex';

const connector = httpConnector({ address: 'http://myapi.com/storex' });
const { useStorex } = prepare({}, connector);

const myStore = useStorex<MyStateType>({
  store: 'myStoreName',
  params: { /* store-specific params */ }
});

// Subscribe to state changes
myStore.subscribe((state) => {
  console.log('New state:', state);
});

// Handle errors
myStore.onError((error) => {
  console.error('An error occurred:', error);
});
```

> [!IMPORTANT]
> Mutations are not supported in HTTP mode
> myStore.commit() will not work as expected

## Configuration

### Session id generation library

You can change library which generate session id for stores. Module needs to have **generate/0** method.

```elixir
config :storex, :session_id_library, Ecto.UUID
```

### Default params

You can set default params for all stores when preparing the Storex instance. These params will be passed to each store.

```typescript
const { useStorex } = prepare({ jwt: 'someJWT' }, connector);
```

### Custom store address

You can specify a custom address when creating the connector:

```typescript
const connector = socketConnector({ address: 'wss://myapi.com/storex' });
// OR
const connector = httpConnector({ address: 'http://myapi.com/storex' });
```