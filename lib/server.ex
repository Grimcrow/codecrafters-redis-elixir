defmodule Server do
  @moduledoc false

  @doc """
  Listen for incoming connections
  """
  def listen() do
    IO.puts("Logs from your program will appear here!")

    {:ok, socket} = :gen_tcp.listen(6378, [:binary, packet: :line, active: false, reuseaddr: true])
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
      {:ok, data} ->
        data
        |> parse_data()
        |> Enum.each(&write_data(client, &1))
      
      {:error, :closed} = resp ->
        write_data(client, resp)
    end

    serve(client)
  end

  defp read_data(client) do
    :gen_tcp.recv(client, 0)
  end

  defp parse_data(data) do
    data
    |> String.trim()
    |> String.split("\\n")
  end

  defp write_data(client, {:error, :closed}) do
    exit(:shutdown)
  end

  defp write_data(client, _data) do
    :gen_tcp.send(client, :unicode.characters_to_binary("$4\r\nPONG\r\n"))
  end
end
