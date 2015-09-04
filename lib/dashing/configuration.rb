require 'redis'
require 'connection_pool'

module Dashing
  class Configuration

    attr_reader   :redis
    attr_accessor :redis_host, :redis_port, :redis_password, :redis_namespace, :redis_timeout
    attr_accessor :auth_token, :devise_allowed_models
    attr_accessor :jobs_path
    attr_accessor :default_dashboard, :dashboards_views_path, :dashboard_layout_path
    attr_accessor :widgets_views_path, :widgets_js_path, :widgets_css_path
    attr_accessor :engine_path

    def initialize
      @engine_path            = '/dashing'

      # Redis
      @redis_host             = URI.parse(ENV["REDIS_URL"]).host
      @redis_port             = URI.parse(ENV["REDIS_URL"]).port
      @redis_password         = URI.parse(ENV["REDIS_URL"]).password
      @redis_namespace        = 'dashing_events'
      @redis_timeout          = 3

      # Authorization
      @auth_token             = nil
      @devise_allowed_models  = []

      # Jobs
      @jobs_path              = -> { Rails.root.join('app', 'jobs') }

      # Dashboards
      @default_dashboard      = nil
      @dashboards_views_path  = -> { Rails.root.join('app', 'views', 'dashing', 'dashboards') }
      @dashboard_layout_path  = 'dashing/dashboard'

      # Widgets
      @widgets_views_path     = Rails.root.join('app', 'views', 'dashing', 'widgets')
      @widgets_js_path        = Rails.root.join('app', 'assets', 'javascripts', 'dashing')
      @widgets_css_path       = Rails.root.join('app', 'assets', 'stylesheets', 'dashing')
    end

    def redis
      @redis ||= ::ConnectionPool::Wrapper.new(size: request_thread_count, timeout: redis_timeout) { new_redis_connection }
    end

    def new_redis_connection
       uri = URI.parse(ENV["REDIS_URL"])
       $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    end

    private

    def request_thread_count
      if defined?(::Puma) && ::Puma.respond_to?(:cli_config)
        ::Puma.cli_config.options.fetch(:max_threads, 5).to_i
      else
        5
      end
    end
  end
end
