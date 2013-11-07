# encoding: utf-8

require 'webrick'

require './lib/bserver/logger'
require './lib/bserver/server_socket'
require './lib/bserver/request_handler'

require './lib/bserver/http_response'


module Bserver
  # Public: класс отвечающий за запуск сервера
  # данный сервер использует наипростейшую архитектуру -
  # каждый принятый запрос обрабатывается в отдельном процессе
  class Server
    include ServerSocket
    include Logger

    def initialize

      @response = HttpResponse.new
      @request = WEBrick::HTTPRequest.new(:Logger => self)

      $stdout.reopen("#{File.dirname(__FILE__)}/../../log/bserver_out.log")
      $stderr.reopen("#{File.dirname(__FILE__)}/../../log/bserver_err.log")
    end

    # Public: запуск сервера
    #
    # addr - String, путь к файлу unix сокета или ip:port
    def run(addr)

      trap_signals

      socket = create_socket(addr)

      info 'Runned'

      loop do

        client_socket, client_addrinfo = socket.accept

        pid = fork do
          begin
            # Обработка запроса
            RequestHandler.new(client_socket, @request, @response).handle
          rescue HttpException => e
            # Установить ошибку в response
            if HttpResponse::HTTP_CODES.has_key?(e.message.to_i)
              @response.set_error(e.message.to_i)
            else
              @response.set_error(500)
            end
          rescue => e
            @response.set_error(500)
            err e.class.name + ':' + e.message
          ensure
            # при любых обстоятельствах сервер должен ответить
            @response.send_response(client_socket)
          end
        end

        client_socket.close

        Process.detach(pid)
      end
    end

    private
    def trap_signals
      [:INT, :QUIT].each do |signal|
        trap(signal) do
          exit
        end
      end
    end

  end
end

