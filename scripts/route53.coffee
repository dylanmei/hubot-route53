# Description:
#   Queries for AWS Route53 information
#
# Dependencies:
#   "aws-sdk": "2.x.x"
#
# Configuration:
#   HUBOT_AWS_ACCESS_KEY_ID
#   HUBOT_AWS_SECRET_ACCESS_KEY
#
# Commands:
#   hubot route53 zones - Returns hosted zones
#   hubot route53 records <filter.?><zone> - Returns a hosted zone's resource records
#
# Author:
#   dylanmei

AWS  = require 'aws-sdk'
util = require 'util'
glob = require 'glob-to-regexp'

config = {
  accessKeyId: process.env.HUBOT_AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.HUBOT_AWS_SECRET_ACCESS_KEY,
}

AWS.config.update config
AWS.config.apiVersions = {
  route53: '2013-04-01'
}

route53 = new AWS.Route53()

find_zones = (msg) ->
  params = { MaxItems: "50" }
  route53.listHostedZones params, (err, data) ->
    if err?
      msg.send util.inspect(err)
      return
    lines = []
    for z in data.HostedZones
      lines.push "#{z.Name} with #{z.ResourceRecordSetCount} records"
    msg.send lines.join('\n')

find_records = (msg, name, filter) ->
  params = { MaxItems: "50" }
  route53.listHostedZones params, (err, data) ->
    if err?
      msg.send util.inspect(err)
      return
    zones = data.HostedZones
    matches = zones.filter (z) -> z.Name.indexOf(name) == 0
    if matches.length == 0
      msg.send "I didn't find a zone named #{name}"
      return
    zone = matches[0]
    params =
      MaxItems: "50",
      HostedZoneId: zone.Id,
    route53.listResourceRecordSets params, (err, data) ->
      if err?
        msg.send util.inspect(err)
        return
      lines = []
      sets = data.ResourceRecordSets
      if filter
        sets = sets.filter (s) ->
          filter.test s.Name[..s.Name.indexOf(zone.Name)-2]
      for s in sets
        values = (r.Value for r in s.ResourceRecords)
        if values.length == 0 and s.AliasTarget
          values = [s.AliasTarget.DNSName]
        lines.push "#{s.Name}"
        lines.push "#{s.Type}: [#{values.join(', ')}]"
      if lines.length > 0
        msg.send lines.join('\n')[..-2]
      else if filter
        msg.send "I didn't find any #{name} resources matching the filter"
      else
        msg.send "I didn't find any #{name} resources"

module.exports = (robot) ->
  robot.hear /route53 zones/i, (msg) ->
    find_zones msg

  robot.hear /route53 records ((.+)\.)?([\w\-]+\.[\w-]+).?/, (msg) ->
    name = msg.match[3]
    filter = glob msg.match[2] if msg.match[2]
    find_records msg, name, filter
