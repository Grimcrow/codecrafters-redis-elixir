defmodule RedisApplication do
  use Application

  alias Server

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Request.TaskSupervisor},
      {Task, fn -> Server.listen() end}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
