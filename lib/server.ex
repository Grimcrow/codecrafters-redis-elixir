defmodule Server do
  @moduledoc false

  @doc """
  Listen for incoming connections
  """

  @pong "+PONG\r\n"

  def listen() do
    IO.puts("Logs from your program will appear here!")

    {:ok, socket} =
      :gen_tcp.listen(6379, [:binary, active: false, reuseaddr: true])

    server(socket)
  end

  defp server(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Request.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)

    server(socket)
  end

  defp serve(client) do
    case read_data(client) do
      {:ok, ""} ->
        write_data(client, {:error, :closed})

      {:ok, command} ->
        command
        |> parse_data()
        |> Enum.each(&write_data(client, &1))

      _ ->
        write_data(client, {:error, :closed})
    end

    serve(client)
  end

  defp read_data(client) do
    :gen_tcp.recv(client, 0)
  end

  defp parse_data(data) do
    data
    |> String.trim()
    |> String.split("\r\n")
    |> parse_resp()
  end

  # Respond only to ping requests
  defp parse_resp(["*" <> arr_count, _, "ping"]) do
    arr_count = String.to_integer(arr_count)
    Enum.map(1..arr_count, fn _ -> :unicode.characters_to_binary(@pong) end)
  end

  defp parse_resp(["*" <> _arr_count, _, "echo", _, data]), do: ["+" <> data <> "\r\n"]

  defp parse_resp(_data), do: []

  defp write_data(_client, {:error, :closed}) do
    exit(:shutdown)
  end

  defp write_data(client, data) do
    :gen_tcp.send(client, data)
  end
end
