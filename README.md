## Quick Start

If [available in Hex](https://hex.pm/packages/bus), the package can be installed as:

1. Add `bus` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:bus, "~> 0.2.0", runtime: false}]
    end
    ```
2. Create your module and add `use Bus` into your module.
   ```elixir
    defmodule Asdf.Bus do
     use Bus
     
     def start_link(_args) do
            Bus.start_link(__MODULE__, [])
     end
   end
   ```

3. Add below details into your supervisor's children list.
    ```elixir
    children = [
      %{
        id: Asdf.Bus,
        start: {Asdf.Bus, :start_link, [[]]}
      }
    ]
    ```
    Where Assdf is the module that will implement behaviour `Bus`.
---

## Note

Detailed Documentation is coming soon.
