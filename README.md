# CheckGraphite

Check graphite metrics

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'check_graphite', '0.1.0', git: 'https://github.com/lscheidler/check_graphite'
```

And then execute:

    $ bundle --binstubs bin

## Usage

### check target againts thresholds

```
bin/check_graphite -u http://localhost:8080 -t collectd.host1.memory.percent-used -c 60 -w 40
```

### calculate percentage from first and second target and check percentage againts thresholds

```
bin/check_graphite -u http://localhost:8080 -t collectd.host1.GenericJMX-lisu_memory-heap.memory-used,collectd.host1.GenericJMX-lisu_memory-heap.memory-max -p -c 90 -w 80
```

### check sum of targets against thresholds

```
bin/check_graphite -u http://localhost:8080 --target=collectd.host1.aggregation-cpu-average.cpu-{system,user} -w 70 -c 90 -s --target-name cpu-usage
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lscheidler/check_graphite.


## License

The gem is available as open source under the terms of the [Apache 2.0 License](http://opensource.org/licenses/Apache-2.0).

