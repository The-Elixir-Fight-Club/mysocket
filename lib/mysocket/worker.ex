defmodule MySocket.Worker do
  use GenServer

  require Logger

  @default_inet_opts [:binary, :inet, {:packet, :raw}, {:active, false}, {:reuseaddr, true}]

  def start_link(port, handler_pid) do
    GenServer.start_link(__MODULE__, [port, handler_pid], name: __MODULE__)
  end

  def init([port, handler_pid]) do
    # listen socket is a port
    {:ok, listen_socket} = :gen_tcp.listen(port, @default_inet_opts)

    acceptor_pid = spawn_link(__MODULE__, :accept_conn, [self(), listen_socket, handler_pid])

    {:ok, %{listen_socket: listen_socket, handler_pid: handler_pid, acceptor_pid: acceptor_pid}}
  end

  @doc """
  Use `{:ok, socket_conn} = :gen_tcp.connect('127.0.0.1', 9001, [:binary, {:packet, 0}])`
  """
  def accept_conn(server, listen_socket, handler_pid) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket_conn} ->
        Logger.info(
          "accepting new connection on listen socket and spawning a new controller process"
        )

        pid_to_control = spawn(fn -> MySocket.Worker.loop(socket_conn, handler_pid) end)

        :ok = :gen_tcp.controlling_process(socket_conn, pid_to_control)

        accept_conn(server, listen_socket, handler_pid)

      error ->
        Logger.error("closing tcp conn due to: #{inspect(error)}")

        :gen_tcp.close(listen_socket)
    end
  end

  def loop(socket_conn, handler_pid) do
    :ok = :inet.setopts(socket_conn, active: :once)

    receive do
      {:tcp, socket_conn, data} ->
        Logger.info(
          "receiving data: #{inspect(data)} from socket conn #{inspect(socket_conn)} at #{
            inspect(self())
          }"
        )

        send(handler_pid, {:data, data})

        loop(socket_conn, handler_pid)

      other_msg ->
        Logger.info("receiving unknown message #{inspect(other_msg)}, closing ...")
    end
  end
end
