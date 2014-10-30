module Dashing
  class EventsController < ApplicationController
    include ActionController::Live

    respond_to :html

    # Since we don't need no database connection in our actions, we release
    # them before doing anything. This is a good practice because we would be
    # holding the database connection until the request is finished, which
    # could take a looooong time.
    #
    # Please read the NOTE below for more info on this subject.
    before_action :release_database_connection

    def index
      response.headers['Content-Type']      = 'text/event-stream'
      response.headers['Cache-Control']     = 'no-cache'
      response.headers['X-Accel-Buffering'] = 'no'

      sse = SSE.new(response.stream)

      redis = Dashing.redis

      # Stream all cached events before anything else
      redis.keys("#{Dashing.config.redis_namespace}:*").each do |key|
        sse.write("#{redis.get(key)}\n\n")
      end

      # NOTE `redis.psubscribe` does block. If your application is not sending
      # events all the time, the `IOError` below would never be rescued, and
      # this `SSE` would never be closed. This would be terrible. To avoid
      # that we open one thread to *tick* the connection once every 5 seconds,
      # and another one to stream any incoming data for us. This grants that
      # the connection will never last more than 5 seconds after the client
      # disconnects. For more information, see:
      #
      # http://evaleverything.com/2013/09/07/response-streams-with-rails-4-and-redis/
      ticker = Thread.new { loop { sse.write 0; sleep 5 } }
      sender = Thread.new do
        redis.psubscribe("#{Dashing.config.redis_namespace}.*") do |on|
          on.pmessage do |pattern, event, data|
            sse.write("#{data}\n\n")
          end
        end
      end

      ticker.join
      sender.join

    rescue IOError
      # Client disconnected
      logger.info "[Dashing][#{Time.now.utc.to_s}] Event stream closed"
    ensure
      Thread.kill(ticker) if ticker
      Thread.kill(sender) if sender
      redis.quit
      sse.close
    end

    private

    def release_database_connection
      ActiveRecord::Base.connection_pool.release_connection
    end

  end
end
