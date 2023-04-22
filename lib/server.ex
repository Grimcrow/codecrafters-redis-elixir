defmodule Server do
  @moduledoc false

  @doc """
  Listen for incoming connections
  """

  @pong "+PONG\r\n"

  @ets_table :kv_store

  def listen() do
    IO.puts("Logs from your program will appear here!")

    {:ok, socket} =
      :gen_tcp.listen(6379, [:binary, active: false, reuseaddr: true])

    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])

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

  defp parse_resp(["*" <> _arr_count, _, "set", _, key, _, value]) do
    :ets.insert(@ets_table, {key, value})
    ["+OK\r\n"]
  end

  # With expiry **
  defp parse_resp(["*" <> _arr_count, _, "set", _, key, _, value, _, "px", _, exp]) do
    {:ok, dt} = DateTime.now("Etc/UTC")
    exp_dt = DateTime.add(dt, String.to_integer(exp), :millisecond)
    :ets.insert(@ets_table, {key, value, exp_dt})
    ["+OK\r\n"]
  end

  defp parse_resp(["*" <> _arr_count, _, "get", _, key]) do
    case :ets.lookup(@ets_table, key) do
      [{_, value}] -> ["+#{value}\r\n"]
      [{_, value, exp_dt}] -> check_if_expired(value, exp_dt)
      [] -> ["+(nil)\r\n"]
    end
  end

  defp parse_resp(_data), do: []

  defp check_if_expired(value, exp_dt) do
    {:ok, dt} = DateTime.now("Etc/UTC")

    if DateTime.compare(exp_dt, dt) |> IO.inspect() == :gt do
      ["+#{value}\r\n"]
    else
      ["$-1\r\n"]
    end
  end

  defp write_data(_client, {:error, :closed}) do
    exit(:shutdown)
  end

  defp write_data(client, data) do
    :gen_tcp.send(client, data)
  end
end
