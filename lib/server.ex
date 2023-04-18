defmodule Server do
  @moduledoc false

  @doc """
  Listen for incoming connections
  """
  def listen() do
    IO.puts("Logs from your program will appear here!")

    {:ok, socket} =
      :gen_tcp.listen(6379, [:binary, packet: :line, active: false, reuseaddr: true])

    server(socket)
  end

  defp server(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Request.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)

    server(socket)
  end

  defp serve(client) do
    case read_data(client, "") do
      {:ok, ""} ->
        write_data(client, {:error, :closed})

      {:ok, command} ->
        command
        |> parse_data()
        |> Enum.each(&write_data(client, &1))

      :error ->
        write_data(client, {:error, :closed})
    end

    serve(client)
  end

  defp read_data(client, command) do
    case :gen_tcp.recv(client, 0, 10) do
      {:ok, data} ->
        read_data(client, command <> data)

      {:error, :closed} ->
        {:ok, command}

      {:error, :timeout} ->
        {:ok, command}

      _ ->
        :error
    end
  end

  defp parse_data(data) do
    data
    |> String.trim()
    |> String.split("\r\n")
    |> parse_resp()
  end

  defp parse_resp(["*" <> arr_count, _, "ping"]) do
    arr_count = String.to_integer(arr_count)
    Enum.map(1..arr_count, fn _ -> "ping" end)
  end

  defp parse_resp(_data), do: []

  defp write_data(_client, {:error, :closed}) do
    exit(:shutdown)
  end

  defp write_data(client, _data) do
    :gen_tcp.send(client, :unicode.characters_to_binary("+PONG\r\n"))
  end
end
