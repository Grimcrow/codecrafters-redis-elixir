defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Request.TaskSupervisor},
      {Task, fn -> Server.listen() end}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  Listen for incoming connections
  """
  def listen() do
    IO.puts("Logs from your program will appear here!")

    {:ok, socket} = :gen_tcp.listen(6379, [:binary, packet: :line, active: false, reuseaddr: true])
    server(socket)
  end

  defp server(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Request.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    server(socket)
  end

  defp serve(client) do
    client
    |> read_data()
    |> parse_data()
    |> Enum.each(&write_data(client, &1))

    serve(client)
  end

  defp read_data(client) do
    {:ok, data} = :gen_tcp.recv(client, 0)
    data
  end

  defp parse_data(data) do
    data
    |> String.trim()
    |> String.split("\\n")
  end

  defp write_data(client, _data) do
    :gen_tcp.send(client, :unicode.characters_to_binary("$4\r\nPONG\r\n"))
  end

end
