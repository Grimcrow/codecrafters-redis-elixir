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
    {:ok, socket} = :gen_tcp.listen(6379, [:binary, packet: :line, active: false, reuseaddr: true])
    server(socket)
  end

  defp server(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    :gen_tcp.send(client, :unicode.characters_to_binary("$4\r\nPONG\r\n"))
    :gen_tcp.shutdown(client, :read)
  end

end
