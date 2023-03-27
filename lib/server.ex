defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  @doc """
  Listen for incoming connections
  """
  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    # Uncomment this block to pass the first stage
    #
    {:ok, socket} = :gen_tcp.listen(6380, [:binary, packet: :line, active: false, reuseaddr: true])
    server(socket)
  end

  defp server(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    serve(client)
    server(socket)
  end

  defp serve(client) do
    client
    |> read_line
    |> write_line(client)

    serve(client)
  end

  defp read_line(client) do
    {:ok, data} = :gen_tcp.recv(client, 0)
    data
  end

  defp write_line(_line, client) do
    :gen_tcp.send(client, "+PONG\r\n")
  end

end
