# Copyright 2018 Lars Eric Scheidler
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "check_graphite/version"

require 'bundler/setup'
require 'json'
require 'net/http'
require 'optparse'

require 'nagios'

# check graphite targets
module CheckGraphite
  # check graphite metrics
  class CLI < Nagios::Plugin
    def initialize
      super do
        parse_arguments
        check_arguments

        run_check
      end
    end

    # set plugin defaults
    def set_plugin_defaults
      @from  = "-2min"
      @until = "now"
      @with_perfdata = false
      @script_name = File.basename $0
      @targets = []
    end

    # parse command line arguments
    def parse_arguments
      @options = OptionParser.new do |opts|
        opts.on('-u', '--graphite-url URL', 'Graphite url') do |graphite_url|
          @graphite_url = graphite_url
        end

        opts.on('-t', '--target NAME', Array, 'Target to check') do |targets|
          @targets += targets
        end

        opts.on('--empty-ok', 'Empty data from graphite is ok') do
          @empty_ok = true
        end

        opts.on('--from TIME', 'set from', 'default: ' + @from) do |from|
          @from = from
        end

        opts.on('--until TIME', 'set until', 'default: ' + @until) do |opt_until|
          @until = opt_until
        end

        opts.on('-c', '--critical VALUE', Integer, 'Critical if datapoints are lower/higher then threshold') do |critical|
          @critical_level = critical
        end

        opts.on('-w', '--warning VALUE', Integer, 'Warning if datapoints are lower/higher then threshold') do |warning|
          @warning_level = warning
        end

        opts.on('-p', '--percentage', 'calculate percentage and check against thresholds, requires two targets') do
          @percentage = true
        end

        opts.on('-s', '--summarize', 'summarize all targets') do
          @summarize = true
        end

        opts.on('--[no-]perfdata', 'add perfdata') do
          @with_perfdata = true
        end

        opts.on('--target-name NAME', 'set name of target') do |target_name|
          @target_name = target_name
        end

        opts.on('--target-regexp REGEXP', 'slice name of target with regexp to get shorter names') do |regexp|
          @target_regexp = regexp
        end

        opts.on('-d', '--debug', 'debug mode') do
          @debug = true
        end

        opts.separator "
examples:
  # check target againts thresholds
  #{@script_name} -u http://localhost:8080 -t collectd.host1.memory.percent-used -c 60 -w 40

  # calculate percentage from first and second target and check percentage againts thresholds
  #{@script_name} -u http://localhost:8080 -t collectd.host1.GenericJMX-lisu_memory-heap.memory-used,collectd.host1.GenericJMX-lisu_memory-heap.memory-max -p -c 90 -w 80

  # check sum of targets against thresholds
  #{@script_name} -u http://localhost:8080 --target=collectd.host1.aggregation-cpu-average.cpu-{system,user} -w 70 -c 90 -s --target-name cpu-usage
"
      end
      @options.parse!
    end

    # check required arguments
    def check_arguments
      raise OptionParser::MissingArgument.new 'Option -c must be set' if @critical_level.nil?
      raise OptionParser::MissingArgument.new 'Option -w must be set' if @warning_level.nil?
      raise OptionParser::MissingArgument.new 'Option -u must be set' if @graphite_url.nil?
      raise OptionParser::MissingArgument.new 'Option -t must be set' if @targets.nil?
    end

    # run check
    def run_check
      datapoints = get_datapoints.compact
      @average = @targets.map do |target|
        target_points = datapoints.find{|x| File.fnmatch(target, x['target'])}
        expect_not_nil target, target_points, msg: 'No datapoints found for ' + target, status: :unknown

        [target, get_average(target_points)]
      end.to_h
      @unknown << 'Percentage calculation needs two targets' if @percentage and datapoints.length < 2 and (datapoints.length%2 != 0)
      exit_with_msg if failed?

      if @percentage
        check_percentage
      elsif @summarize
        check_sum
      else
        check_all
      end
    end

    # take two target, first as value, second as maximum and check percentage againts thresholds
    def check_percentage
      while not @average.empty?
        value_name, value = @average.shift
        max = @average.shift.last
        expect_percentage_level target_name(value_name), value, max, warning_level: @warning_level, critical_level: @critical_level
      end
    end

    # summarize all targets and check this against thresholds
    def check_sum
      name = target_name(@average.first.first)
      value = @average.map{|key, v| v}.reduce(:+)
      expect_level name, value, warning_level: @warning_level, critical_level: @critical_level
    end

    # check all targets against thresholds
    def check_all
      @average.each do |key, value|
        expect_level target_name(key), value, warning_level: @warning_level, critical_level: @critical_level
      end
    end

    # retrieve datapoints from graphite
    def get_datapoints
      uri = URI(
              @graphite_url + '/render?format=json' +
              '&target=' + @targets.join('&target=') +
              '&from=' + @from +
              '&until=' + @until
            )

      req = Net::HTTP::Get.new(uri)
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(req)
      end

      if res.class != Net::HTTPOK
        raise res.class.to_s
      end

      begin
        JSON::parse(res.body)
      rescue JSON::ParserError => e
        raise e.class.to_s
      end
    end

    # calculate average from datapoints
    #
    # @param data [Hash] target result from graphite
    def get_average data
      if data.nil? or data['datapoints'].nil?
        nil
      else
        d = data['datapoints'].map{|x| x.first}.compact
        d.reduce(:+) / d.length
      end
    end

    # return target name
    #
    # @param target [String] target
    def target_name target
      if @target_name
        @target_name
      elsif @target_regexp
        target.slice(/#{@target_regexp}/)
      else
        target
      end
    end
  end
end
