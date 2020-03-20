/usr/bin/perl
 This script can initialize, upgrade or provide simple maintenance for the
 moloch elastic search db

 Schema Versions
  0 - Before this script existed
  1 - First version of scri turned on strict sche added lpms, fp added
      many missing items that were dynamically created by mistake
  2 - Added email items
  3 - Added email md5
  4 - Added email host and  added help, usersimport, usersexport, wipe commands
  5 - No schema change, new rotate command, encoding of file pos is different.
      Negative is file num, positive is file pos
  6 - Multi fields for spi view, added xffcnt, 0.90 fixes, need to type INIT/UPGRADE
      instead of YES
  7 - files_v3
  8 - fileSize, memory to stats/dstats and -v flag
  9 - http body hash, rawus
 10 - dynamic fields for http and email headers
 11 - Require 0.90.1, switch from soft to node, new fpd field, removed fpms field
 12 - Added hsver, hdver fields, diskQueue, user settings, scrub* fields, user removeEnabled
 13 - Rename rotate to expire, added smb, socks, rir fields
 14 - New http fields, user.views
 15 - New first byte fields, socks user
 16 - New dynamic plugin section
 17 - email hasheader, db,pa,by src and dst
 18 - fields db
 19 - users_v3
 20 - queries
 21 - doc_values, new tls fields, starttime/stoptime/view
 22 - cpu to stats/dstats
 23 - packet lengths
 24 - field category
 25 - cert hash
 26 - dynamic stats, ES 2.0
 27 - table states
 28 - timestamp, firstPacket, lastPacket, ipSrc, ipDst, portSrc, portSrc
 29 - stats/dstats uses dynamic_templates
 30 - change file to dynamic
 31 - Require ES >= 2.4, dstats_v2, stats_v1
 32 - Require ES >= 2.4 or ES >= 5.1.2, tags_v3, queries_v1, fields_v1, users_v4, files_v4, sequence_v1
 33 - user columnConfigs
 34 - stats_v2
 35 - user spiviewFieldConfigs
 36 - user action history
 37 - add request body to history
 50 - Moloch 1.0
 51 - Upgrade for ES 6.x: sequence_v2, fields_v2, queries_v2, files_v5, users_v5, dstats_v3, stats_v3
 52 - Hunt (packet search)
 53 - add forcedExpression to history
 54 - users_v6
 55 - user hideStats, hideFiles, hidePcap, and disablePcapDownload
 56 - notifiers
 57 - hunt notifiers
 58 - users message count and last used date
 59 - tokens
 60 - users time query limit
 61 - shortcuts
 62 - hunt error timestamp and node
 63 - Upgrade for ES 7.x: sequence_v3, fields_v3, queries_v3, files_v6, users_v7, dstats_v4, stats_v4, hunts_v2
 64 - lock shortcuts

use HTTP::Request::Common
use LWP::UserAgent
use JSON
use Data::Dumper
use POSIX
use IO::Compress::Gzip qw(gzip $GzipError)
use stri

my $VERSION =
my $verbose =
my $PREFIX =
my $SECURE =
my $CLIENTCERT =
my $CLIENTKEY =
my $NOCHANGES =
my $SHARDS =
my $REPLICAS =
my $HISTORY =
my $SEGMENTS =
my $SEGMENTSMIN =
my $NOOPTIMIZE =
my $FULL =
my $REVERSE =
my $SHARDSPERNODE =
my $ESTIMEOUT=
my $UPGRADEALLSESSIONS =
my $DOHOTWARM =
my $DOILM =
my $WARMAFTER =
my $WARMKIND = "dail
my $OPTIMIZEWARM =
my $TYPE = "strin
my $SHARED =
my $DESCRIPTION =
my $LOCKED =
my $GZ =
my $REFRESH =

use LWP::ConsoleLogger::Everywhere


sub MIN ($$) { $_[$_[0] > $_[1]] }
sub MAX ($$) { $_[$_[0] < $_[1]] }

sub commify {
    scalar reverse join ',',
    unpack '(A3)*',
    scalar reverse shift
}


sub logmsg
{
  local $| =
  print (scalar localtime() . " ") if ($verbose >
  print ("@_
}

sub showHelp($)
{
    my ($str) =
    print "\n", $str,"\n\
    print "$0 [Global Options] <ESHOST:ESPORT> <command> [<command arguments>]\
    print "\
    print "Global Options:\
    print "  -v                           - Verbose, multiple increases level\
    print "  --prefix <prefix>            - Prefix for table names\
    print "  --clientkey <keypath>        - Path to key for client authentication.  Must not have a passphrase.\
    print "  --clientcert <certpath>      - Path to cert for client authentication\
    print "  --insecure                   - Don't verify http certificates\
    print "  -n                           - Make no db changes\
    print "  --timeout <timeout>          - Timeout in seconds for ES, default 60\
    print "\
    print "General Commands:\
    print "  info                         - Information about the database\
    print "  init [<opts>]                - Clear ALL elasticsearch moloch data and create schema\
    print "    --shards <shards>          - Number of shards for sessions, default number of nodes\
    print "    --replicas <num>           - Number of replicas for sessions, default 0\
    print "    --refresh <num>            - Number of seconds for ES refresh interval for sessions indices, default 60\
    print "    --shardsPerNode <shards>   - Number of shards per node or use \"null\" to let ES decide, default shards*replicas/nodes\
    print "    --hotwarm                  - Set 'hot' for 'node.attr.molochtype' on new indices, warm on non sessions indices\
    print "    --ilm                      - Use ilm to manage\
    print "  wipe                         - Same as init, but leaves user database untouched\
    print "  upgrade [<opts>]             - Upgrade Moloch's schema in elasticsearch from previous versions\
    print "    --shards <shards>          - Number of shards for sessions, default number of nodes\
    print "    --replicas <num>           - Number of replicas for sessions, default 0\
    print "    --refresh <num>            - Number of seconds for ES refresh interval for sessions indices, default 60\
    print "    --shardsPerNode <shards>   - Number of shards per node or use \"null\" to let ES decide, default shards*replicas/nodes\
    print "    --hotwarm                  - Set 'hot' for 'node.attr.molochtype' on new indices, warm on non sessions indices\
    print "    --ilm                      - Use ilm to manage\
    print "  expire <type> <num> [<opts>] - Perform daily ES maintenance and optimize all indices in ES\
    print "       type                    - Same as rotateIndex in ini file = hourly,hourlyN,daily,weekly,monthly\
    print "       num                     - number of indexes to keep\
    print "    --replicas <num>           - Number of replicas for older sessions indices, default 0\
    print "    --nooptimize               - Do not optimize session indexes during this operation\
    print "    --history <num>            - Number of weeks of history to keep, default 13\
    print "    --segments <num>           - Number of segments to optimize sessions to, default 1\
    print "    --segmentsmin <num>        - Only optimize indices with at least <num> segments, default is <segments> \
    print "    --reverse                  - Optimize from most recent to oldest\
    print "    --shardsPerNode <shards>   - Number of shards per node or use \"null\" to let ES decide, default shards*replicas/nodes\
    print "    --warmafter <wafter>       - Set molochwarm on indices after <wafter> <type>\
    print "    --optmizewarm              - Only optimize warm green indices\
    print "  optimize                     - Optimize all moloch indices in ES\
    print "    --segments <num>           - Number of segments to optimize sessions to, default 1\
    print "  optimize-admin               - Optimize only admin indices in ES, use with ILM\
    print "  disable-users <days>         - Disable user accounts that have not been active\
    print "      days                     - Number of days of inactivity (integer)\
    print "  set-shortcut <name> <userid> <file> [<opts>]\
    print "       name                    - Name of the shortcut (no special characters except '_')\
    print "       userid                  - UserId of the user to add the shortcut for\
    print "       file                    - File that includes a comma or newline separated list of values\
    print "    --type <type>              - Type of shortcut = string, ip, number, default is string\
    print "    --shared                   - Whether the shortcut is shared to all users\
    print "    --description <description>- Description of the shortcut\
    print "    --locked                   - Whether the shortcut is locked and cannot be modified by the web interface\
    print "  shrink <index> <node> <num>  - Shrink a session index\
    print "      index                    - The session index to shrink\
    print "      node                     - The node to temporarily use for shrinking\
    print "      num                      - Number of shards to shrink to\
    print "    --shardsPerNode <shards>   - Number of shards per node or use \"null\" to let ES decide, default 1\
    print "  ilm <force> <delete>         - Create ILM profile\
    print "      force                    - Time in hours/days before (moving to warm) and force merge (number followed by h or d)\
    print "      delete                   - Time in hours/days before deleting index (number followed by h or d)\
    print "    --hotwarm                  - Set 'hot' for 'node.attr.molochtype' on new indices, warm on non sessions indices\
    print "    --segments <num>           - Number of segments to optimize sessions to, default 1\
    print "    --replicas <num>           - Number of replicas for older sessions indices, default 0\
    print "    --history <num>            - Number of weeks of history to keep, default 13\
    print "\
    print "Backup and Restore Commands:\
    print "  backup <basename> <opts>     - Backup everything but sessio filenames created start with <basename>\
    print "    --gz                       - GZip the files\
    print "  restore <basename> [<opts>]  - Restore everything but sessio filenames restored from start with <basename>\
    print "    --skipupgradeall           - Do not upgrade Sessions\
    print "  export <index> <basename>    - Save a single index into a file, filename starts with <basename>\
    print "  import <filename>            - Import single index from <filename>\
    print "  users-export <filename>      - Save the users info to <filename>\
    print "  users-import <filename>      - Load the users info from <filename>\
    print "\
    print "File Commands:\
    print "  mv <old fn> <new fn>         - Move a pcap file in the database (doesn't change disk)\
    print "  rm <fn>                      - Remove a pcap file in the database (doesn't change disk)\
    print "  rm-missing <node>            - Remove from db any MISSING files on THIS machine for the named node\
    print "  add-missing <node> <dir>     - Add to db any MISSING files on THIS machine for named node and directory\
    print "  sync-files  <nodes> <dirs>   - Add/Remove in db any MISSING files on THIS machine for named node(s) and directory(s), both comma separated\
    print "\
    print "Field Commands:\
    print "  field disable <exp>          - disable a field from being indexed\
    print "  field enable <exp>           - enable a field from being indexed\
    print "\
    print "Node Commands:\
    print "  rm-node <node>               - Remove from db all data for node (doesn't change disk)\
    print "  add-alias <node> <hostname>  - Adds a hidden node that points to hostname\
    print "  hide-node <node>             - Hide node in stats display\
    print "  unhide-node <node>           - Unhide node in stats display\
    print "\
    print "ES maintenance\
    print "  set-replicas <pat> <num>              - Set the number of replicas for index pattern\
    print "  set-shards-per-node <pat> <num>       - Set the number of replicas for index pattern\
    print "  set-allocation-enable <mode>          - Set the allocation mode (all, primaries, new_primaries, none, null)\
    print "  allocate-empty <node> <index> <shard> - Allocate a empty shard on a node, DATA LOSS!\
    print "  unflood-stage <pat>                   - Mark index pattern as no longer flooded\
    exit
}

sub waitFor
{
    my ($str, $help) =

    print "Type \"$str\" to continue - $help?\
    while (1) {
        my $answer = <STDI
        chomp $answ
        last if ($answer eq $st
        print "You didn't type \"$str\", for some reason you typed \"$answer\"\
    }
}

sub waitForRE
{
    my ($re, $help) =

    print "$help\
    while (1) {
        my $answer = <STDI
        chomp $answ
        return $answer if ($answer =~ $r
        print "$help\
    }
}


sub esIndexExists
{
    my ($index) =
    logmsg "HEAD ${main::elasticsearch}/$index\n" if ($verbose >
    my $response = $main::userAgent->head("${main::elasticsearch}/$index
    logmsg "HEAD RESULT:", $response->code, "\n" if ($verbose >
    return $response->code == 2
}

sub esCheckAlias
{
    my ($alias, $index) =
    my $result = esGet("/_alias/$alias",

    return (exists $result->{$index} && exists $result->{$index}->{aliases}->{$alias
}

sub esGet
{
    my ($url, $dontcheck) =
    logmsg "GET ${main::elasticsearch}$url\n" if ($verbose >
    my $response = $main::userAgent->get("${main::elasticsearch}$url
    if (($response->code == 500 && $ARGV[1] ne "init" && $ARGV[1] ne "shrink") || ($response->code != 200 && !$dontcheck)) {
      die "Couldn't GET ${main::elasticsearch}$url  the http status code is " . $response->code . " are you sure elasticsearch is running/reachable
    }
    my $json = from_json($response->conten
    logmsg "GET RESULT:", Dumper($json), "\n" if ($verbose >
    return $json
}


sub esPost
{
    my ($url, $content, $dontcheck) =

    if ($NOCHANGES && $url !~ /_search/) {
      logmsg "NOCHANGE: POST ${main::elasticsearch}$url\
      retu
    }

    logmsg "POST ${main::elasticsearch}$url\n" if ($verbose >
    logmsg "POST DATA:", Dumper($content), "\n" if ($verbose >
    my $response = $main::userAgent->post("${main::elasticsearch}$url", Content => $content, Content_Type => "application/json
    if ($response->code == 500 || ($response->code != 200 && $response->code != 201 && !$dontcheck)) {
      return from_json("{}") if ($dontcheck ==

      logmsg "POST RESULT:", $response->content, "\n" if ($verbose >
      die "Couldn't POST ${main::elasticsearch}$url  the http status code is " . $response->code . " are you sure elasticsearch is running/reachable
    }

    my $json = from_json($response->conten
    logmsg "POST RESULT:", Dumper($json), "\n" if ($verbose >
    return $json
}


sub esPut
{
    my ($url, $content, $dontcheck) =

    if ($NOCHANGES) {
      logmsg "NOCHANGE: PUT ${main::elasticsearch}$url\
      retu
    }

    logmsg "PUT ${main::elasticsearch}$url\n" if ($verbose >
    logmsg "PUT DATA:", Dumper($content), "\n" if ($verbose >
    my $response = $main::userAgent->request(HTTP::Request::Common::PUT("${main::elasticsearch}$url", Content => $content, Content_Type => "application/json"
    if ($response->code == 500 || ($response->code != 200 && !$dontcheck)) {
      logmsg Dumper($respons
      die "Couldn't PUT ${main::elasticsearch}$url  the http status code is " . $response->code . " are you sure elasticsearch is running/reachable?\n" . $response->conte
    }

    my $json = from_json($response->conten
    logmsg "PUT RESULT:", Dumper($json), "\n" if ($verbose >
    return $json
}


sub esDelete
{
    my ($url, $dontcheck) =

    if ($NOCHANGES) {
      logmsg "NOCHANGE: DELETE ${main::elasticsearch}$url\
      retu
    }

    logmsg "DELETE ${main::elasticsearch}$url\n" if ($verbose >
    my $response = $main::userAgent->request(HTTP::Request::Common::_simple_req("DELETE", "${main::elasticsearch}$url"
    if ($response->code == 500 || ($response->code != 200 && !$dontcheck)) {
      die "Couldn't DELETE ${main::elasticsearch}$url  the http status code is " . $response->code . " are you sure elasticsearch is running/reachable
    }
    my $json = from_json($response->conten
    return $json
}


sub esCopy
{
    my ($srci, $dsti) =

    $main::userAgent->timeout(720

    my $status = esGet("/_stats/docs",
    logmsg "Copying " . $status->{indices}->{$PREFIX . $srci}->{primaries}->{docs}->{count} . " elements from ${PREFIX}$srci to ${PREFIX}$dsti\

    esPost("/_reindex?timeout=7200s", to_json({"source" => {"index" => $PREFIX.$srci}, "dest" => {"index" => $PREFIX.$dsti, "version_type" => "external"}, "conflicts" => "proceed"}

    my $status = esGet("/${PREFIX}${dsti}/_refresh",
    my $status = esGet("/_stats/docs",
    if ($status->{indices}->{$PREFIX . $srci}->{primaries}->{docs}->{count} > $status->{indices}->{$PREFIX . $dsti}->{primaries}->{docs}->{count}) {
        logmsg $status->{indices}->{$PREFIX . $srci}->{primaries}->{docs}->{count}, " > ",  $status->{indices}->{$PREFIX . $dsti}->{primaries}->{docs}->{count}, "\
        die "\nERROR - Copy failed from $srci to $dsti, you will probably need to delete $dsti and run upgrade again.  Make sure to not change the index while upgrading.\n\
    }

    logmsg "\
    $main::userAgent->timeout($ESTIMEOUT +
}

sub esScroll
{
    my ($index, $type, $query) =

    my @hits =

    my $id =
    while (1) {
        if ($verbose > 0) {
            local $| =
            print "
        }
        my $u
        if ($id eq "") {
            if ($type eq "") {
                $url = "/${PREFIX}$index/_search?scroll=10m&size=50
            } else {
                $url = "/${PREFIX}$index/$type/_search?scroll=10m&size=50
            }
        } else {
            $url = "/_search/scroll?scroll=10m&scroll_id=$i
            $query =
        }


        my $incoming = esPost($url, $query,
        die Dumper($incoming) if ($incoming->{status} == 40
        last if (@{$incoming->{hits}->{hits}} ==

        push(@hits, @{$incoming->{hits}->{hits}

        $id = $incoming->{_scroll_i
    }
    return \@hi
}

sub esAlias
{
    my ($cmd, $index, $alias, $dontaddprefix) =
    logmsg "Alias cmd $cmd from $index to alias $alias\n" if ($verbose >
    if (!$dontaddprefix){  append PREFIX
    esPost("/_aliases?master_timeout=${ESTIMEOUT}s", '{ "actions": [ { "' . $cmd . '": { "index": "' . $PREFIX . $index . '", "alias" : "'. $PREFIX . $alias .'" } } ] }',
    } else {  do not append PREFIX
        esPost("/_aliases?master_timeout=${ESTIMEOUT}s", '{ "actions": [ { "' . $cmd . '": { "index": "' . $index . '", "alias" : "'. $alias .'" } } ] }',
    }
}


sub esWaitForNoTask
{
    my ($str) =
    while (1) {
        logmsg "GET ${main::elasticsearch}/_cat/tasks\n" if ($verbose >
        my $response = $main::userAgent->get("${main::elasticsearch}/_cat/tasks
        if ($response->code != 200) {
            sleep(3
        }

        return 1 if (index ($response->content, $str) == -
        sleep
    }
}

sub esForceMerge
{
    my ($index, $segments, $dowait) =
    esWaitForNoTask("forcemerge") if ($dowai
    esPost("/$index/_forcemerge?max_num_segments=$segments", "",
    esWaitForNoTask("forcemerge") if ($dowai
}


sub sequenceCreate
{
    my $settings = '
{
  "settings": {
    "index.priority": 100,
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "auto_expand_replicas": "0-3"
  }


    logmsg "Creating sequence_v3 index\n" if ($verbose >
    esPut("/${PREFIX}sequence_v3?master_timeout=${ESTIMEOUT}s", $settings,
    esAlias("add", "sequence_v3", "sequence
    sequenceUpdate
}


sub sequenceUpdate
{
    my $mapping = '
{
  "sequence": {
    "_source" : { "enabled": "false" },
    "enabled" : "false"
  }


    logmsg "Setting sequence_v3 mapping\n" if ($verbose >
    esPut("/${PREFIX}sequence_v3/sequence/_mapping?master_timeout=${ESTIMEOUT}s&include_type_name=true", $mappin
}

sub sequenceUpgrade
{

    if (esCheckAlias("${PREFIX}sequence", "${PREFIX}sequence_v3") && esIndexExists("${PREFIX}sequence_v3")) {
        logmsg ("SKIPPING - ${PREFIX}sequence already points to ${PREFIX}sequence_v3\n
        retu
    }

    $main::userAgent->timeout(720
    sequenceCreate
    esAlias("remove", "sequence_v2", "sequence
    my $results = esGet("/${PREFIX}sequence_v2/_search?version=true&size=10000",

    logmsg "Copying " . $results->{hits}->{total} . " elements from ${PREFIX}sequence_v2 to ${PREFIX}sequence_v3\

    return if ($results->{hits}->{total} ==

    foreach my $hit (@{$results->{hits}->{hits}}) {
        if ($hit->{_id} =~ /^fn-/) {
            esPost("/${PREFIX}sequence_v3/sequence/$hit->{_id}?timeout=${ESTIMEOUT}s&version_type=external&version=$hit->{_version}", "{}",
        }
    }
    esDelete("/${PREFIX}sequence_v2
    $main::userAgent->timeout($ESTIMEOUT +
}

sub filesCreate
{
    my $settings = '
{
  "settings": {
    "index.priority": 80,
    "number_of_shards": 2,
    "number_of_replicas": 0,
    "auto_expand_replicas": "0-3"
  }


    logmsg "Creating files_v6 index\n" if ($verbose >
    esPut("/${PREFIX}files_v6?master_timeout=${ESTIMEOUT}s", $setting
    esAlias("add", "files_v6", "files
    filesUpdate
}

sub filesUpdate
{
    my $mapping = '
{
  "file": {
    "_source": {"enabled": "true"},
    "dynamic": "true",
    "dynamic_templates": [
      {
        "any": {
          "match": "*",
          "mapping": {
            "index": false
          }
        }
      }
    ],
    "properties": {
      "num": {
        "type": "long"
      },
      "node": {
        "type": "keyword"
      },
      "first": {
        "type": "long"
      },
      "name": {
        "type": "keyword"
      },
      "filesize": {
        "type": "long"
      },
      "locked": {
        "type": "short"
      },
      "last": {
        "type": "long"
      }
    }
  }


    logmsg "Setting files_v6 mapping\n" if ($verbose >
    esPut("/${PREFIX}files_v6/file/_mapping?master_timeout=${ESTIMEOUT}s&include_type_name=true", $mappin
}

sub statsCreate
{
    my $settings = '
{
  "settings": {
    "index.priority": 70,
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "auto_expand_replicas": "0-3"
  }


    logmsg "Creating stats index\n" if ($verbose >
    esPut("/${PREFIX}stats_v4?master_timeout=${ESTIMEOUT}s", $setting
    esAlias("add", "stats_v4", "stats
    statsUpdate
}


sub statsUpdate
{
my $mapping = '
{
  "stat": {
    "_source": {"enabled": "true"},
    "dynamic": "true",
    "dynamic_templates": [
      {
        "numeric": {
          "match_mapping_type": "long",
          "mapping": {
            "type": "long"
          }
        }
      }
    ],
    "properties": {
      "hostname": {
        "type": "keyword"
      },
      "nodeName": {
        "type": "keyword"
      },
      "currentTime": {
        "type": "date",
        "format": "epoch_second"
      }
    }
  }


    logmsg "Setting stats mapping\n" if ($verbose >
    esPut("/${PREFIX}stats_v4/stat/_mapping?master_timeout=${ESTIMEOUT}s&pretty&include_type_name=true", $mapping,
}

sub dstatsCreate
{
    my $settings = '
{
  "settings": {
    "index.priority": 50,
    "number_of_shards": 2,
    "number_of_replicas": 0,
    "auto_expand_replicas": "0-3"
  }


    logmsg "Creating dstats_v4 index\n" if ($verbose >
    esPut("/${PREFIX}dstats_v4?master_timeout=${ESTIMEOUT}s", $setting
    esAlias("add", "dstats_v4", "dstats
    dstatsUpdate
}


sub dstatsUpdate
{
my $mapping = '
{
  "dstat": {
    "_source": {"enabled": "true"},
    "dynamic": "true",
    "dynamic_templates": [
      {
        "numeric": {
          "match_mapping_type": "long",
          "mapping": {
            "type": "long",
            "index": false
          }
        }
      },
      {
        "noindex": {
          "match": "*",
          "mapping": {
            "index": false
          }
        }
      }
    ],
    "properties": {
      "nodeName": {
        "type": "keyword"
      },
      "interval": {
        "type": "short"
      },
      "currentTime": {
        "type": "date",
        "format": "epoch_second"
      }
    }
  }


    logmsg "Setting dstats_v4 mapping\n" if ($verbose >
    esPut("/${PREFIX}dstats_v4/dstat/_mapping?master_timeout=${ESTIMEOUT}s&pretty&include_type_name=true", $mapping,
}

sub fieldsCreate
{
    my $settings = '
{
  "settings": {
    "index.priority": 90,
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "auto_expand_replicas": "0-3"
  }


    logmsg "Creating fields index\n" if ($verbose >
    esPut("/${PREFIX}fields_v3?master_timeout=${ESTIMEOUT}s", $setting
    esAlias("add", "fields_v3", "fields
    fieldsUpdate
}

 Not the fix I want, but it works for now
sub fieldsIpDst
{
    esPost("/${PREFIX}fields_v3/field/ip.dst?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Dst IP",
      "group": "general",
      "help": "Destination IP",
      "type": "ip",
      "dbField": "a2",
      "dbField2": "dstIp",
      "portField": "p2",
      "portField2": "dstPort",
      "category": "ip",
      "aliases": ["ip.dst:port"]
    }
}

sub fieldsUpdate
{
    my $mapping = '
{
  "field": {
    "_source": {"enabled": "true"},
    "dynamic_templates": [
      {
        "string_template": {
          "match_mapping_type": "string",
          "mapping": {
            "type": "keyword"
          }
        }
      }
    ]
  }


    logmsg "Setting fields_v3 mapping\n" if ($verbose >
    esPut("/${PREFIX}fields_v3/field/_mapping?master_timeout=${ESTIMEOUT}s&include_type_name=true", $mappin

    esPost("/${PREFIX}fields_v3/field/ip?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "All IP fields",
      "group": "general",
      "help": "Search all ip fields",
      "type": "ip",
      "dbField": "ipall",
      "dbField2": "ipall",
      "portField": "portall",
      "noFacet": "true"
    }
    esPost("/${PREFIX}fields_v3/field/port?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "All port fields",
      "group": "general",
      "help": "Search all port fields",
      "type": "integer",
      "dbField": "portall",
      "dbField2": "portall",
      "regex": "(^port\\\\.(?:(?!\\\\.cnt$).)*$|\\\\.port$)"
    }
    esPost("/${PREFIX}fields_v3/field/rir?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "All rir fields",
      "group": "general",
      "help": "Search all rir fields",
      "type": "uptermfield",
      "dbField": "rirall",
      "dbField2": "rirall",
      "regex": "(^rir\\\\.(?:(?!\\\\.cnt$).)*$|\\\\.rir$)"
    }
    esPost("/${PREFIX}fields_v3/field/country?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "All country fields",
      "group": "general",
      "help": "Search all country fields",
      "type": "uptermfield",
      "dbField": "geoall",
      "dbField2": "geoall",
      "regex": "(^country\\\\.(?:(?!\\\\.cnt$).)*$|\\\\.country$)"
    }
    esPost("/${PREFIX}fields_v3/field/asn?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "All ASN fields",
      "group": "general",
      "help": "Search all ASN fields",
      "type": "termfield",
      "dbField": "asnall",
      "dbField2": "asnall",
      "regex": "(^asn\\\\.(?:(?!\\\\.cnt$).)*$|\\\\.asn$)"
    }
    esPost("/${PREFIX}fields_v3/field/host?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "All Host fields",
      "group": "general",
      "help": "Search all Host fields",
      "type": "lotermfield",
      "dbField": "hostall",
      "dbField2": "hostall",
      "regex": "(^host\\\\.(?:(?!\\\\.(cnt|tokens)$).)*$|\\\\.host$)"
    }
    esPost("/${PREFIX}fields_v3/field/ip.src?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Src IP",
      "group": "general",
      "help": "Source IP",
      "type": "ip",
      "dbField": "a1",
      "dbField2": "srcIp",
      "portField": "p1",
      "portField2": "srcPort",
      "category": "ip"
    }
    esPost("/${PREFIX}fields_v3/field/port.src?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Src Port",
      "group": "general",
      "help": "Source Port",
      "type": "integer",
      "dbField": "p1",
      "dbField2": "srcPort",
      "category": "port"
    }
    esPost("/${PREFIX}fields_v3/field/asn.src?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Src ASN",
      "group": "general",
      "help": "GeoIP ASN string calculated from the source IP",
      "type": "termfield",
      "dbField": "as1",
      "dbField2": "srcASN",
      "rawField": "rawas1",
      "category": "asn"
    }
    esPost("/${PREFIX}fields_v3/field/country.src?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Src Country",
      "group": "general",
      "help": "Source Country",
      "type": "uptermfield",
      "dbField": "g1",
      "dbField2": "srcGEO",
      "category": "country"
    }
    esPost("/${PREFIX}fields_v3/field/rir.src?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Src RIR",
      "group": "general",
      "help": "Source RIR",
      "type": "uptermfield",
      "dbField": "rir1",
      "dbField2": "srcRIR",
      "category": "rir"
    }
    fieldsIpDst
    esPost("/${PREFIX}fields_v3/field/port.dst?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Dst Port",
      "group": "general",
      "help": "Source Port",
      "type": "integer",
      "dbField": "p2",
      "dbField2": "dstPort",
      "category": "port"
    }
    esPost("/${PREFIX}fields_v3/field/asn.dst?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Dst ASN",
      "group": "general",
      "help": "GeoIP ASN string calculated from the destination IP",
      "type": "termfield",
      "dbField": "as2",
      "dbField2": "dstASN",
      "rawField": "rawas2",
      "category": "asn"
    }
    esPost("/${PREFIX}fields_v3/field/country.dst?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Dst Country",
      "group": "general",
      "help": "Destination Country",
      "type": "uptermfield",
      "dbField": "g2",
      "dbField2": "dstGEO",
      "category": "country"
    }
    esPost("/${PREFIX}fields_v3/field/rir.dst?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Dst RIR",
      "group": "general",
      "help": "Destination RIR",
      "type": "uptermfield",
      "dbField": "rir2",
      "dbField2": "dstRIR",
      "category": "rir"
    }
    esPost("/${PREFIX}fields_v3/field/bytes?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Bytes",
      "group": "general",
      "help": "Total number of raw bytes sent AND received in a session",
      "type": "integer",
      "dbField": "by",
      "dbField2": "totBytes"
    }
    esPost("/${PREFIX}fields_v3/field/bytes.src?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Src Bytes",
      "group": "general",
      "help": "Total number of raw bytes sent by source in a session",
      "type": "integer",
      "dbField": "by1",
      "dbField2": "srcBytes"
    }
    esPost("/${PREFIX}fields_v3/field/bytes.dst?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Dst Bytes",
      "group": "general",
      "help": "Total number of raw bytes sent by destination in a session",
      "type": "integer",
      "dbField": "by2",
      "dbField2": "dstBytes"
    }
    esPost("/${PREFIX}fields_v3/field/databytes?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Data bytes",
      "group": "general",
      "help": "Total number of data bytes sent AND received in a session",
      "type": "integer",
      "dbField": "db",
      "dbField2": "totDataBytes"
    }
    esPost("/${PREFIX}fields_v3/field/databytes.src?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Src data bytes",
      "group": "general",
      "help": "Total number of data bytes sent by source in a session",
      "type": "integer",
      "dbField": "db1",
      "dbField2": "srcDataBytes"
    }
    esPost("/${PREFIX}fields_v3/field/databytes.dst?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Dst data bytes",
      "group": "general",
      "help": "Total number of data bytes sent by destination in a session",
      "type": "integer",
      "dbField": "db2",
      "dbField2": "dstDataBytes"
    }
    esPost("/${PREFIX}fields_v3/field/packets?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Packets",
      "group": "general",
      "help": "Total number of packets sent AND received in a session",
      "type": "integer",
      "dbField": "pa",
      "dbField2": "totPackets"
    }
    esPost("/${PREFIX}fields_v3/field/packets.src?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Src Packets",
      "group": "general",
      "help": "Total number of packets sent by source in a session",
      "type": "integer",
      "dbField": "pa1",
      "dbField2": "srcPackets"
    }
    esPost("/${PREFIX}fields_v3/field/packets.dst?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Dst Packets",
      "group": "general",
      "help": "Total number of packets sent by destination in a session",
      "type": "integer",
      "dbField": "pa2",
      "dbField2": "dstPackets"
    }
    esPost("/${PREFIX}fields_v3/field/ip.protocol?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "IP Protocol",
      "group": "general",
      "help": "IP protocol number or friendly name",
      "type": "lotermfield",
      "dbField": "pr",
      "dbField2": "ipProtocol",
      "transform": "ipProtocolLookup"
    }
    esPost("/${PREFIX}fields_v3/field/id?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Moloch ID",
      "group": "general",
      "help": "Moloch ID for the session",
      "type": "termfield",
      "dbField": "_id",
      "dbField2": "_id",
      "noFacet": "true"

    }
    esPost("/${PREFIX}fields_v3/field/rootId?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Moloch Root ID",
      "group": "general",
      "help": "Moloch ID of the first session in a multi session stream",
      "type": "termfield",
      "dbField": "ro",
      "dbField2": "rootId"
    }
    esPost("/${PREFIX}fields_v3/field/node?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Moloch Node",
      "group": "general",
      "help": "Moloch node name the session was recorded on",
      "type": "termfield",
      "dbField": "no",
      "dbField2": "node"
    }
    esPost("/${PREFIX}fields_v3/field/file?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Filename",
      "group": "general",
      "help": "Moloch offline pcap filename",
      "type": "fileand",
      "dbField": "fileand",
      "dbField2": "fileand"
    }
    esPost("/${PREFIX}fields_v3/field/payload8.src.hex?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Payload Src Hex",
      "group": "general",
      "help": "First 8 bytes of source payload in hex",
      "type": "lotermfield",
      "dbField": "fb1",
      "dbField2": "srcPayload8",
      "aliases": ["payload.src"]
    }
    esPost("/${PREFIX}fields_v3/field/payload8.src.utf8?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Payload Src UTF8",
      "group": "general",
      "help": "First 8 bytes of source payload in utf8",
      "type": "termfield",
      "dbField": "fb1",
      "dbField2": "srcPayload8",
      "transform": "utf8ToHex",
      "noFacet": "true"
    }
    esPost("/${PREFIX}fields_v3/field/payload8.dst.hex?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Payload Dst Hex",
      "group": "general",
      "help": "First 8 bytes of destination payload in hex",
      "type": "lotermfield",
      "dbField": "fb2",
      "dbField2": "dstPayload8",
      "aliases": ["payload.dst"]
    }
    esPost("/${PREFIX}fields_v3/field/payload8.dst.utf8?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Payload Dst UTF8",
      "group": "general",
      "help": "First 8 bytes of destination payload in utf8",
      "type": "termfield",
      "dbField": "fb2",
      "dbField2": "dstPayload8",
      "transform": "utf8ToHex",
      "noFacet": "true"
    }
    esPost("/${PREFIX}fields_v3/field/payload8.hex?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Payload Hex",
      "group": "general",
      "help": "First 8 bytes of payload in hex",
      "type": "lotermfield",
      "dbField": "fballhex",
      "dbField2": "fballhex",
      "regex": "^payload8.(src|dst).hex$"
    }
    esPost("/${PREFIX}fields_v3/field/payload8.utf8?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Payload UTF8",
      "group": "general",
      "help": "First 8 bytes of payload in hex",
      "type": "lotermfield",
      "dbField": "fballutf8",
      "dbField2": "fballutf8",
      "regex": "^payload8.(src|dst).utf8$"
    }
    esPost("/${PREFIX}fields_v3/field/scrubbed.by?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Scrubbed By",
      "group": "general",
      "help": "SPI data was scrubbed by",
      "type": "lotermfield",
      "dbField": "scrubby",
      "dbField2": "scrubby"
    }
    esPost("/${PREFIX}fields_v3/field/view?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "View Name",
      "group": "general",
      "help": "Moloch view name",
      "type": "viewand",
      "dbField": "viewand",
      "dbField2": "viewand",
      "noFacet": "true"
    }
    esPost("/${PREFIX}fields_v3/field/starttime?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Start Time",
      "group": "general",
      "help": "Session Start Time",
      "type": "seconds",
      "type2": "date",
      "dbField": "fp",
      "dbField2": "firstPacket"
    }
    esPost("/${PREFIX}fields_v3/field/stoptime?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Stop Time",
      "group": "general",
      "help": "Session Stop Time",
      "type": "seconds",
      "type2": "date",
      "dbField": "lp",
      "dbField2": "lastPacket"
    }
    esPost("/${PREFIX}fields_v3/field/huntId?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Hunt ID",
      "group": "general",
      "help": "The ID of the packet search job that matched this session",
      "type": "termfield",
      "dbField": "huntId",
      "dbField2": "huntId"
    }
    esPost("/${PREFIX}fields_v3/field/huntName?timeout=${ESTIMEOUT}s", '{
      "friendlyName": "Hunt Name",
      "group": "general",
      "help": "The name of the packet search job that matched this session",
      "type": "termfield",
      "dbField": "huntName",
      "dbField2": "huntName"
    }
}


sub queriesCreate
{
    my $settings = '
{
  "settings": {
    "index.priority": 40,
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "auto_expand_replicas": "0-3"
  }


    logmsg "Creating queries index\n" if ($verbose >
    esPut("/${PREFIX}queries_v3?master_timeout=${ESTIMEOUT}s", $setting
    queriesUpdate
}

sub queriesUpdate
{
    my $mapping = '
{
  "query": {
    "_source": {"enabled": "true"},
    "dynamic": "strict",
    "properties": {
      "name": {
        "type": "keyword"
      },
      "enabled": {
        "type": "boolean"
      },
      "lpValue": {
        "type": "long"
      },
      "lastRun": {
        "type": "date"
      },
      "count": {
        "type": "long"
      },
      "query": {
        "type": "keyword"
      },
      "action": {
        "type": "keyword"
      },
      "creator": {
        "type": "keyword"
      },
      "tags": {
        "type": "keyword"
      },
      "notifier": {
        "type": "keyword"
      },
      "lastNotified": {
        "type": "date"
      },
      "lastNotifiedCount": {
        "type": "long"
      }
    }
  }


    logmsg "Setting queries mapping\n" if ($verbose >
    esPut("/${PREFIX}queries_v3/query/_mapping?master_timeout=${ESTIMEOUT}s&pretty&include_type_name=true", $mappin
    esAlias("add", "queries_v3", "queries
}


 Create the template sessions use and update mapping of current sessions.
 Not all fields need to be here, but the index will be created quicker if more are.
sub sessions2Update
{
    my $mapping = '
{
  "session": {
    "_meta": {
      "molochDbVersion": ' . $VERSION . '
    },
    "dynamic": "true",
    "dynamic_templates": [
      {
        "template_ip_end": {
          "match": "*Ip",
          "mapping": {
            "type": "ip"
          }
        }
      },
      {
        "template_ip_alone": {
          "match": "ip",
          "mapping": {
            "type": "ip"
          }
        }
      },
      {
        "template_word_split": {
          "match": "*Tokens",
          "mapping": {
            "analyzer": "wordSplit",
            "type": "text",
            "norms": false
          }
        }
      },
      {
        "template_string": {
          "match_mapping_type": "string",
          "mapping": {
            "type": "keyword"
          }
        }
      }
    ],
    "properties" : {
      "asset" : {
        "type" : "keyword"
      },
      "assetCnt" : {
        "type" : "long"
      },
      "cert" : {
        "properties" : {
          "alt" : {
            "type" : "keyword"
          },
          "altCnt" : {
            "type" : "long"
          },
          "curve" : {
            "type" : "keyword"
          },
          "hash" : {
            "type" : "keyword"
          },
          "issuerCN" : {
            "type" : "keyword"
          },
          "issuerON" : {
            "type" : "keyword"
          },
          "notAfter" : {
            "type" : "date"
          },
          "notBefore" : {
            "type" : "date"
          },
          "publicAlgorithm" : {
            "type" : "keyword"
          },
          "remainingDays" : {
            "type" : "long"
          },
          "serial" : {
            "type" : "keyword"
          },
          "subjectCN" : {
            "type" : "keyword"
          },
          "subjectON" : {
            "type" : "keyword"
          },
          "validDays" : {
            "type" : "long"
          }
        }
      },
      "certCnt" : {
        "type" : "long"
      },
      "communityId" : {
        "type" : "keyword"
      },
      "dhcp" : {
        "properties" : {
          "host" : {
            "type" : "keyword",
            "copy_to" : [
              "dhcp.hostTokens"
            ]
          },
          "hostCnt" : {
            "type" : "long"
          },
          "hostTokens" : {
            "type" : "text",
            "norms" : false,
            "analyzer" : "wordSplit"
          },
          "id" : {
            "type" : "keyword"
          },
          "idCnt" : {
            "type" : "long"
          },
          "mac" : {
            "type" : "keyword"
          },
          "macCnt" : {
            "type" : "long"
          },
          "oui" : {
            "type" : "keyword"
          },
          "ouiCnt" : {
            "type" : "long"
          },
          "type" : {
            "type" : "keyword"
          },
          "typeCnt" : {
            "type" : "long"
          }
        }
      },
      "dns" : {
        "properties" : {
          "ASN" : {
            "type" : "keyword"
          },
          "GEO" : {
            "type" : "keyword"
          },
          "RIR" : {
            "type" : "keyword"
          },
          "host" : {
            "type" : "keyword",
            "copy_to" : [
              "dns.hostTokens"
            ]
          },
          "hostCnt" : {
            "type" : "long"
          },
          "hostTokens" : {
            "type" : "text",
            "norms" : false,
            "analyzer" : "wordSplit"
          },
          "ip" : {
            "type" : "ip"
          },
          "ipCnt" : {
            "type" : "long"
          },
          "opcode" : {
            "type" : "keyword"
          },
          "opcodeCnt" : {
            "type" : "long"
          },
          "puny" : {
            "type" : "keyword"
          },
          "punyCnt" : {
            "type" : "long"
          },
          "qc" : {
            "type" : "keyword"
          },
          "qcCnt" : {
            "type" : "long"
          },
          "qt" : {
            "type" : "keyword"
          },
          "qtCnt" : {
            "type" : "long"
          },
          "status" : {
            "type" : "keyword"
          },
          "statusCnt" : {
            "type" : "long"
          }
        }
      },
      "dstASN" : {
        "type" : "keyword"
      },
      "dstBytes" : {
        "type" : "long"
      },
      "dstDataBytes" : {
        "type" : "long"
      },
      "dstGEO" : {
        "type" : "keyword"
      },
      "dstIp" : {
        "type" : "ip"
      },
      "dstMac" : {
        "type" : "keyword"
      },
      "dstMacCnt" : {
        "type" : "long"
      },
      "dstOui" : {
        "type" : "keyword"
      },
      "dstOuiCnt" : {
        "type" : "long"
      },
      "dstPackets" : {
        "type" : "long"
      },
      "dstPayload8" : {
        "type" : "keyword"
      },
      "dstPort" : {
        "type" : "long"
      },
      "dstRIR" : {
        "type" : "keyword"
      },
      "email" : {
        "properties" : {
	  "ASN" : {
	    "type" : "keyword"
	  },
	  "GEO" : {
	    "type" : "keyword"
	  },
	  "RIR" : {
	    "type" : "keyword"
	  },
          "bodyMagic" : {
            "type" : "keyword"
          },
          "bodyMagicCnt" : {
            "type" : "long"
          },
          "contentType" : {
            "type" : "keyword"
          },
          "contentTypeCnt" : {
            "type" : "long"
          },
          "dst" : {
            "type" : "keyword"
          },
          "dstCnt" : {
            "type" : "long"
          },
          "filename" : {
            "type" : "keyword"
          },
          "filenameCnt" : {
            "type" : "long"
          },
          "header" : {
            "type" : "keyword"
          },
          "header-chad" : {
            "type" : "keyword"
          },
          "header-chadCnt" : {
            "type" : "long"
          },
          "headerCnt" : {
            "type" : "long"
          },
          "host" : {
            "type" : "keyword",
            "copy_to" : [
              "email.hostTokens"
            ]
          },
          "hostCnt" : {
            "type" : "long"
          },
          "hostTokens" : {
            "type" : "text",
            "norms" : false,
            "analyzer" : "wordSplit"
          },
          "id" : {
            "type" : "keyword"
          },
          "idCnt" : {
            "type" : "long"
          },
	  "ip" : {
	    "type" : "ip"
	  },
	  "ipCnt" : {
	    "type" : "long"
	  },
          "md5" : {
            "type" : "keyword"
          },
          "md5Cnt" : {
            "type" : "long"
          },
          "mimeVersion" : {
            "type" : "keyword"
          },
          "mimeVersionCnt" : {
            "type" : "long"
          },
	  "smtpHello" : {
	    "type" : "keyword"
	  },
	  "smtpHelloCnt" : {
	    "type" : "long"
	  },
          "src" : {
            "type" : "keyword"
          },
          "srcCnt" : {
            "type" : "long"
          },
          "subject" : {
            "type" : "keyword"
          },
          "subjectCnt" : {
            "type" : "long"
          },
          "useragent" : {
            "type" : "keyword"
          },
          "useragentCnt" : {
            "type" : "long"
          }
        }
      },
      "fileId" : {
        "type" : "long"
      },
      "firstPacket" : {
        "type" : "date"
      },
      "http" : {
        "properties" : {
          "authType" : {
            "type" : "keyword"
          },
          "authTypeCnt" : {
            "type" : "long"
          },
          "bodyMagic" : {
            "type" : "keyword"
          },
          "bodyMagicCnt" : {
            "type" : "long"
          },
          "clientVersion" : {
            "type" : "keyword"
          },
          "clientVersionCnt" : {
            "type" : "long"
          },
          "cookieKey" : {
            "type" : "keyword"
          },
          "cookieKeyCnt" : {
            "type" : "long"
          },
          "cookieValue" : {
            "type" : "keyword"
          },
          "cookieValueCnt" : {
            "type" : "long"
          },
          "host" : {
            "type" : "keyword",
            "copy_to" : [
              "http.hostTokens"
            ]
          },
          "hostCnt" : {
            "type" : "long"
          },
          "hostTokens" : {
            "type" : "text",
            "norms" : false,
            "analyzer" : "wordSplit"
          },
          "key" : {
            "type" : "keyword"
          },
          "keyCnt" : {
            "type" : "long"
          },
          "md5" : {
            "type" : "keyword"
          },
          "md5Cnt" : {
            "type" : "long"
          },
          "method" : {
            "type" : "keyword"
          },
          "methodCnt" : {
            "type" : "long"
          },
          "path" : {
            "type" : "keyword"
          },
          "pathCnt" : {
            "type" : "long"
          },
          "request-authorization" : {
            "type" : "keyword"
          },
          "request-authorizationCnt" : {
            "type" : "long"
          },
          "request-chad" : {
            "type" : "keyword"
          },
          "request-chadCnt" : {
            "type" : "long"
          },
          "request-content-type" : {
            "type" : "keyword"
          },
          "request-content-typeCnt" : {
            "type" : "long"
          },
          "request-origin" : {
            "type" : "keyword"
          },
          "request-referer" : {
            "type" : "keyword"
          },
          "request-refererCnt" : {
            "type" : "long"
          },
          "requestBody" : {
            "type" : "keyword"
          },
          "requestHeader" : {
            "type" : "keyword"
          },
          "requestHeaderCnt" : {
            "type" : "long"
          },
          "response-content-type" : {
            "type" : "keyword"
          },
          "response-content-typeCnt" : {
            "type" : "long"
          },
          "response-location" : {
            "type" : "keyword"
          },
          "response-server" : {
            "type" : "keyword"
          },
          "responseHeader" : {
            "type" : "keyword"
          },
          "responseHeaderCnt" : {
            "type" : "long"
          },
          "serverVersion" : {
            "type" : "keyword"
          },
          "serverVersionCnt" : {
            "type" : "long"
          },
          "statuscode" : {
            "type" : "long"
          },
          "statuscodeCnt" : {
            "type" : "long"
          },
          "uri" : {
            "type" : "keyword",
            "copy_to" : [
              "http.uriTokens"
            ]
          },
          "uriCnt" : {
            "type" : "long"
          },
          "uriTokens" : {
            "type" : "text",
            "norms" : false,
            "analyzer" : "wordSplit"
          },
          "user" : {
            "type" : "keyword"
          },
          "userCnt" : {
            "type" : "long"
          },
          "useragent" : {
            "type" : "keyword",
            "copy_to" : [
              "http.useragentTokens"
            ]
          },
          "useragentCnt" : {
            "type" : "long"
          },
          "useragentTokens" : {
            "type" : "text",
            "norms" : false,
            "analyzer" : "wordSplit"
          },
          "value" : {
            "type" : "keyword"
          },
          "valueCnt" : {
            "type" : "long"
          },
          "xffASN" : {
            "type" : "keyword"
          },
          "xffGEO" : {
            "type" : "keyword"
          },
          "xffIp" : {
            "type" : "ip"
          },
          "xffIpCnt" : {
            "type" : "long"
          },
          "xffRIR" : {
            "type" : "keyword"
          }
        }
      },
      "icmp" : {
        "properties" : {
          "code" : {
            "type" : "long"
          },
          "type" : {
            "type" : "long"
          }
        }
      },
      "initRTT" : {
        "type" : "long"
      },
      "ipProtocol" : {
        "type" : "long"
      },
      "irc" : {
        "properties" : {
          "channel" : {
            "type" : "keyword"
          },
          "channelCnt" : {
            "type" : "long"
          },
          "nick" : {
            "type" : "keyword"
          },
          "nickCnt" : {
            "type" : "long"
          }
        }
      },
      "krb5" : {
        "properties" : {
          "cname" : {
            "type" : "keyword"
          },
          "cnameCnt" : {
            "type" : "long"
          },
          "realm" : {
            "type" : "keyword"
          },
          "realmCnt" : {
            "type" : "long"
          },
          "sname" : {
            "type" : "keyword"
          },
          "snameCnt" : {
            "type" : "long"
          }
        }
      },
      "lastPacket" : {
        "type" : "date"
      },
      "ldap" : {
        "properties" : {
          "authtype" : {
            "type" : "keyword"
          },
          "authtypeCnt" : {
            "type" : "long"
          },
          "bindname" : {
            "type" : "keyword"
          },
          "bindnameCnt" : {
            "type" : "long"
          }
        }
      },
      "length" : {
        "type" : "long"
      },
      "mysql" : {
        "properties" : {
          "user" : {
            "type" : "keyword"
          },
          "version" : {
            "type" : "keyword"
          }
        }
      },
      "node" : {
        "type" : "keyword"
      },
      "oracle" : {
        "properties" : {
          "host" : {
            "type" : "keyword",
            "copy_to" : [
              "oracle.hostTokens"
            ]
          },
          "hostTokens" : {
            "type" : "text",
            "norms" : false,
            "analyzer" : "wordSplit"
          },
          "service" : {
            "type" : "keyword"
          },
          "user" : {
            "type" : "keyword"
          }
        }
      },
      "packetLen" : {
        "type" : "integer",
        "index" : false
      },
      "packetPos" : {
        "type" : "long",
        "index" : false
      },
      "postgresql" : {
        "properties" : {
          "app" : {
            "type" : "keyword"
          },
          "db" : {
            "type" : "keyword"
          },
          "user" : {
            "type" : "keyword"
          }
        }
      },
      "protocol" : {
        "type" : "keyword"
      },
      "protocolCnt" : {
        "type" : "long"
      },
      "quic" : {
        "properties" : {
          "host" : {
            "type" : "keyword",
            "copy_to" : [
              "quic.hostTokens"
            ]
          },
          "hostCnt" : {
            "type" : "long"
          },
          "hostTokens" : {
            "type" : "text",
            "norms" : false,
            "analyzer" : "wordSplit"
          },
          "useragent" : {
            "type" : "keyword",
            "copy_to" : [
              "quic.useragentTokens"
            ]
          },
          "useragentCnt" : {
            "type" : "long"
          },
          "useragentTokens" : {
            "type" : "text",
            "norms" : false,
            "analyzer" : "wordSplit"
          },
          "version" : {
            "type" : "keyword"
          },
          "versionCnt" : {
            "type" : "long"
          }
        }
      },
      "radius" : {
        "properties" : {
          "framedASN" : {
            "type" : "keyword"
          },
          "framedGEO" : {
            "type" : "keyword"
          },
          "framedIp" : {
            "type" : "ip"
          },
          "framedIpCnt" : {
            "type" : "long"
          },
          "framedRIR" : {
            "type" : "keyword"
          },
          "mac" : {
            "type" : "keyword"
          },
          "macCnt" : {
            "type" : "long"
          },
          "user" : {
            "type" : "keyword"
          }
        }
      },
      "rootId" : {
        "type" : "keyword"
      },
      "segmentCnt" : {
        "type" : "long"
      },
      "smb" : {
        "properties" : {
          "filename" : {
            "type" : "keyword"
          },
          "filenameCnt" : {
            "type" : "long"
          },
          "host" : {
            "type" : "keyword",
            "copy_to" : [
              "smb.hostTokens"
            ]
          }
        }
      },
      "socks" : {
        "properties" : {
          "ASN" : {
            "type" : "keyword"
          },
          "GEO" : {
            "type" : "keyword"
          },
          "RIR" : {
            "type" : "keyword"
          },
          "host" : {
            "type" : "keyword",
            "copy_to" : [
              "socks.hostTokens"
            ]
          },
          "ip" : {
            "type" : "ip"
          },
          "port" : {
            "type" : "long"
          },
          "user" : {
            "type" : "keyword"
          }
        }
      },
      "srcASN" : {
        "type" : "keyword"
      },
      "srcBytes" : {
        "type" : "long"
      },
      "srcDataBytes" : {
        "type" : "long"
      },
      "srcGEO" : {
        "type" : "keyword"
      },
      "srcIp" : {
        "type" : "ip"
      },
      "srcMac" : {
        "type" : "keyword"
      },
      "srcMacCnt" : {
        "type" : "long"
      },
      "srcOui" : {
        "type" : "keyword"
      },
      "srcOuiCnt" : {
        "type" : "long"
      },
      "srcPackets" : {
        "type" : "long"
      },
      "srcPayload8" : {
        "type" : "keyword"
      },
      "srcPort" : {
        "type" : "long"
      },
      "srcRIR" : {
        "type" : "keyword"
      },
      "ssh" : {
        "properties" : {
          "hassh" : {
            "type" : "keyword"
          },
          "hasshCnt" : {
            "type" : "long"
          },
          "hasshServer" : {
            "type" : "keyword"
          },
          "hasshServerCnt" : {
            "type" : "long"
          },
          "key" : {
            "type" : "keyword"
          },
          "keyCnt" : {
            "type" : "long"
          },
          "version" : {
            "type" : "keyword"
          },
          "versionCnt" : {
            "type" : "long"
          }
        }
      },
      "suricata" : {
	"properties" : {
	  "action" : {
	    "type" : "keyword"
	  },
	  "actionCnt" : {
	    "type" : "long"
	  },
	  "category" : {
	    "type" : "keyword"
	  },
	  "categoryCnt" : {
	    "type" : "long"
	  },
	  "flowId" : {
	    "type" : "keyword"
	  },
	  "flowIdCnt" : {
	    "type" : "long"
	  },
	  "gid" : {
	    "type" : "long"
	  },
	  "gidCnt" : {
	    "type" : "long"
	  },
	  "severity" : {
	    "type" : "long"
	  },
	  "severityCnt" : {
	    "type" : "long"
	  },
	  "signature" : {
	    "type" : "keyword"
	  },
	  "signatureCnt" : {
	    "type" : "long"
	  },
	  "signatureId" : {
	    "type" : "long"
	  },
	  "signatureIdCnt" : {
	    "type" : "long"
	  }
	}
      },
      "tags" : {
        "type" : "keyword"
      },
      "tagsCnt" : {
        "type" : "long"
      },
      "tcpflags" : {
        "properties" : {
          "ack" : {
            "type" : "long"
          },
          "dstZero" : {
            "type" : "long"
          },
          "fin" : {
            "type" : "long"
          },
          "psh" : {
            "type" : "long"
          },
          "rst" : {
            "type" : "long"
          },
          "srcZero" : {
            "type" : "long"
          },
          "syn" : {
            "type" : "long"
          },
          "syn-ack" : {
            "type" : "long"
          },
          "urg" : {
            "type" : "long"
          }
        }
      },
      "timestamp" : {
        "type" : "date"
      },
      "tls" : {
        "properties" : {
          "cipher" : {
            "type" : "keyword"
          },
          "cipherCnt" : {
            "type" : "long"
          },
          "dstSessionId" : {
            "type" : "keyword"
          },
          "ja3" : {
            "type" : "keyword"
          },
          "ja3Cnt" : {
            "type" : "long"
          },
          "ja3s" : {
            "type" : "keyword"
          },
          "ja3sCnt" : {
            "type" : "long"
          },
          "srcSessionId" : {
            "type" : "keyword"
          },
          "version" : {
            "type" : "keyword"
          },
          "versionCnt" : {
            "type" : "long"
          }
        }
      },
      "totBytes" : {
        "type" : "long"
      },
      "totDataBytes" : {
        "type" : "long"
      },
      "totPackets" : {
        "type" : "long"
      },
      "user" : {
        "type" : "keyword"
      },
      "userCnt" : {
        "type" : "long"
      },
      "vlan" : {
        "type" : "long"
      },
      "vlanCnt" : {
        "type" : "long"
      }
    }
  }
}

$REPLICAS = 0 if ($REPLICAS <
my $shardsPerNode = ceil($SHARDS * ($REPLICAS+1) / $main::numberOfNode
$shardsPerNode = $SHARDSPERNODE if ($SHARDSPERNODE eq "null" || $SHARDSPERNODE > $shardsPerNod

my $settings =
if ($DOHOTWARM) {
  $settings .= ',
      "routing.allocation.require.molochtype": "hot
}

if ($DOILM) {
  $settings .= qq/,
      "lifecycle.name": "${PREFIX}molochsessions
}

    my $template = '
{
  "index_patterns": "' . $PREFIX . 'sessions2-*",
  "settings": {
    "index": {
      "routing.allocation.total_shards_per_node": ' . $shardsPerNode . $settings . ',
      "refresh_interval": "' . $REFRESH . 's",
      "number_of_shards": ' . $SHARDS . ',
      "number_of_replicas": ' . $REPLICAS . ',
      "analysis": {
        "analyzer": {
          "wordSplit": {
            "type": "custom",
            "tokenizer": "pattern",
            "filter": ["lowercase"]
          }
        }
      }
    }
  },
  "mappings":' . $mapping . '


    logmsg "Creating sessions template\n" if ($verbose >
    esPut("/_template/${PREFIX}sessions2_template?master_timeout=${ESTIMEOUT}s&pretty&include_type_name=true", $templat

    my $indices = esGet("/${PREFIX}sessions2-*/_alias",

    if ($UPGRADEALLSESSIONS) {
        logmsg "Updating sessions2 mapping for ", scalar(keys %{$indices}), " indices\n" if (scalar(keys %{$indices}) !=
        foreach my $i (keys %{$indices}) {
            progress("$i
            esPut("/$i/session/_mapping?master_timeout=${ESTIMEOUT}s&include_type_name=true", $mapping,
        }
        logmsg "\
    }
}


sub historyUpdate
{
    my $mapping = '
{
  "history": {
    "_source": {"enabled": "true"},
    "dynamic": "strict",
    "properties": {
      "uiPage": {
        "type": "keyword"
      },
      "userId": {
        "type": "keyword"
      },
      "method": {
        "type": "keyword"
      },
      "api": {
        "type": "keyword"
      },
      "expression": {
        "type": "keyword"
      },
      "view": {
        "type": "object",
        "dynamic": "true"
      },
      "timestamp": {
        "type": "date",
        "format": "epoch_second"
      },
      "range": {
        "type": "integer"
      },
      "query": {
        "type": "keyword"
      },
      "queryTime": {
        "type": "integer"
      },
      "recordsReturned": {
        "type": "integer"
      },
      "recordsFiltered": {
        "type": "long"
      },
      "recordsTotal": {
        "type": "long"
      },
      "body": {
        "type": "object",
        "dynamic": "true"
      },
      "forcedExpression": {
        "type": "keyword"
      }
    }
  }


my $settings =
if ($DOILM) {
  $settings .= qq/"lifecycle.name": "${PREFIX}molochhistory",
}

 my $template = qq/
{
  "index_patterns": "${PREFIX}history_v1-*",
  "settings": {
      ${settings}
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "auto_expand_replicas": "0-1"
    },
  "mappings": ${mapping}


logmsg "Creating history template\n" if ($verbose >
esPut("/_template/${PREFIX}history_v1_template?master_timeout=${ESTIMEOUT}s&pretty&include_type_name=true", $templat

my $indices = esGet("/${PREFIX}history_v1-*/_alias",

if ($UPGRADEALLSESSIONS) {
    logmsg "Updating history mapping for ", scalar(keys %{$indices}), " indices\n" if (scalar(keys %{$indices}) !=
    foreach my $i (keys %{$indices}) {
        progress("$i
        esPut("/$i/history/_mapping?master_timeout=${ESTIMEOUT}s&include_type_name=true", $mapping,
    }
}

logmsg "\
}



sub huntsCreate
{
  my $settings = '
{
  "settings": {
    "index.priority": 30,
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "auto_expand_replicas": "0-3"
  }


  logmsg "Creating hunts_v2 index\n" if ($verbose >
  esPut("/${PREFIX}hunts_v2?master_timeout=${ESTIMEOUT}s", $setting
  esAlias("add", "hunts_v2", "hunts
  huntsUpdate
}

sub huntsUpdate
{
    my $mapping = '
{
  "hunt": {
    "_source": {"enabled": "true"},
    "dynamic": "strict",
    "properties": {
      "userId": {
        "type": "keyword"
      },
      "status": {
        "type": "keyword"
      },
      "name": {
        "type": "keyword"
      },
      "size": {
        "type": "integer"
      },
      "search": {
        "type": "keyword"
      },
      "searchType": {
        "type": "keyword"
      },
      "src": {
        "type": "boolean"
      },
      "dst": {
        "type": "boolean"
      },
      "type": {
        "type": "keyword"
      },
      "matchedSessions": {
        "type": "integer"
      },
      "searchedSessions": {
        "type": "integer"
      },
      "totalSessions": {
        "type": "integer"
      },
      "lastPacketTime": {
        "type": "date"
      },
      "created": {
        "type": "date"
      },
      "lastUpdated": {
        "type": "date"
      },
      "started": {
        "type": "date"
      },
      "query": {
        "type": "object",
        "dynamic": "true"
      },
      "errors": {
        "properties": {
          "value": {
            "type": "keyword"
          },
          "time": {
            "type": "date"
          },
          "node": {
            "type": "keyword"
          }
        }
      },
      "notifier": {
        "type": "keyword"
      }
    }
  }


logmsg "Setting hunts_v2 mapping\n" if ($verbose >
esPut("/${PREFIX}hunts_v2/hunt/_mapping?master_timeout=${ESTIMEOUT}s&pretty&include_type_name=true", $mappin
}



sub lookupsCreate
{
  my $settings = '
{
  "settings": {
    "index.priority": 30,
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "auto_expand_replicas": "0-3"
  }


  logmsg "Creating lookups_v1 index\n" if ($verbose >
  esPut("/${PREFIX}lookups_v1?master_timeout=${ESTIMEOUT}s", $setting
  esAlias("add", "lookups_v1", "lookups
  lookupsUpdate
}

sub lookupsUpdate
{
    my $mapping = '
{
  "lookup": {
    "_source": {"enabled": "true"},
    "dynamic": "strict",
    "properties": {
      "userId": {
        "type": "keyword"
      },
      "name": {
        "type": "keyword"
      },
      "shared": {
        "type": "boolean"
      },
      "description": {
        "type": "keyword"
      },
      "number": {
        "type": "integer"
      },
      "ip": {
        "type": "keyword"
      },
      "string": {
        "type": "keyword"
      },
      "locked": {
        "type": "boolean"
      }
    }
  }


logmsg "Setting lookups_v1 mapping\n" if ($verbose >
esPut("/${PREFIX}lookups_v1/lookup/_mapping?master_timeout=${ESTIMEOUT}s&pretty&include_type_name=true", $mappin
}



sub usersCreate
{
    my $settings = '
{
  "settings": {
    "index.priority": 60,
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "auto_expand_replicas": "0-3"
  }


    logmsg "Creating users_v7 index\n" if ($verbose >
    esPut("/${PREFIX}users_v7?master_timeout=${ESTIMEOUT}s", $setting
    esAlias("add", "users_v7", "users
    usersUpdate
}

sub usersUpdate
{
    my $mapping = '
{
  "user": {
    "_source": {"enabled": "true"},
    "dynamic": "strict",
    "properties": {
      "userId": {
        "type": "keyword"
      },
      "userName": {
        "type": "keyword"
      },
      "enabled": {
        "type": "boolean"
      },
      "createEnabled": {
        "type": "boolean"
      },
      "webEnabled": {
        "type": "boolean"
      },
      "headerAuthEnabled": {
        "type": "boolean"
      },
      "emailSearch": {
        "type": "boolean"
      },
      "removeEnabled": {
        "type": "boolean"
      },
      "packetSearch": {
        "type": "boolean"
      },
      "hideStats": {
        "type": "boolean"
      },
      "hideFiles": {
        "type": "boolean"
      },
      "hidePcap": {
        "type": "boolean"
      },
      "disablePcapDownload": {
        "type": "boolean"
      },
      "passStore": {
        "type": "keyword"
      },
      "expression": {
        "type": "keyword"
      },
      "settings": {
        "type": "object",
        "dynamic": "true"
      },
      "views": {
        "type": "object",
        "dynamic": "true",
        "enabled": "false"
      },
      "notifiers": {
        "type": "object",
        "dynamic": "true",
        "enabled": "false"
      },
      "columnConfigs": {
        "type": "object",
        "dynamic": "true",
        "enabled": "false"
      },
      "spiviewFieldConfigs": {
        "type": "object",
        "dynamic": "true",
        "enabled": "false"
      },
      "tableStates": {
        "type": "object",
        "dynamic": "true",
        "enabled": "false"
      },
      "welcomeMsgNum": {
        "type": "integer"
      },
      "lastUsed": {
        "type": "date"
      },
      "timeLimit": {
        "type": "integer"
      }
    }
  }


    logmsg "Setting users_v7 mapping\n" if ($verbose >
    esPut("/${PREFIX}users_v7/user/_mapping?master_timeout=${ESTIMEOUT}s&pretty&include_type_name=true", $mappin
}

sub setPriority
{
    esPut("/${PREFIX}sequence/_settings?master_timeout=${ESTIMEOUT}s", '{"settings": {"index.priority": 100}}',
    esPut("/${PREFIX}fields/_settings?master_timeout=${ESTIMEOUT}s", '{"settings": {"index.priority": 90}}',
    esPut("/${PREFIX}files/_settings?master_timeout=${ESTIMEOUT}s", '{"settings": {"index.priority": 80}}',
    esPut("/${PREFIX}stats/_settings?master_timeout=${ESTIMEOUT}s", '{"settings": {"index.priority": 70}}',
    esPut("/${PREFIX}users/_settings?master_timeout=${ESTIMEOUT}s", '{"settings": {"index.priority": 60}}',
    esPut("/${PREFIX}dstats/_settings?master_timeout=${ESTIMEOUT}s", '{"settings": {"index.priority": 50}}',
    esPut("/${PREFIX}queries/_settings?master_timeout=${ESTIMEOUT}s", '{"settings": {"index.priority": 40}}',
    esPut("/${PREFIX}hunts/_settings?master_timeout=${ESTIMEOUT}s", '{"settings": {"index.priority": 30}}',
}

sub createNewAliasesFromOld
{
    my ($alias, $newName, $oldName, $createFunction) =

    if (esCheckAlias("${PREFIX}$alias", "${PREFIX}$newName") && esIndexExists("${PREFIX}$newName")) {
        logmsg ("SKIPPING - ${PREFIX}$alias already points to ${PREFIX}$newName\n
        retu
    }

    if (!esIndexExists("${PREFIX}$oldName")) {
        die "ERROR - ${PREFIX}$oldName doesn't exist
    }

    $createFunction->
    esAlias("remove", $oldName, $alia
    esCopy($oldName, $newNam
    esDelete("/${PREFIX}${oldName}",
}

sub kind2time
{
    my ($kind, $num) =

    my @theTime = gmti

    if ($kind eq "hourly") {
        $theTime[2] -= $n
    } elsif ($kind =~ /^hourly([23468])$/) {
        $theTime[2] -= $num * int($
    } elsif ($kind eq "hourly12") {
        $theTime[2] -= $num *
    } elsif ($kind eq "daily") {
        $theTime[3] -= $n
    } elsif ($kind eq "weekly") {
        $theTime[3] -= 7*$n
    } elsif ($kind eq "monthly") {
        $theTime[4] -= $n
    }

    return @theTi
}

sub mktimegm
{
  local $ENV{TZ} = 'UT
  return mktime(@
}

sub index2time
{
my($index) =

  return 0 if ($index !~ /sessions2-(.*)$
  $index =

  my

  $t[0] =
  $t[1] =
  $t[5] = int (substr($index, 0, 2
  $t[5] += 100 if ($t[5] < 5

  if ($index =~ /m/) {
      $t[2] =
      $t[3] =
      $t[4] = int(substr($index, 3, 2)) -
  } elsif ($index =~ /w/) {
      $t[2] =
      $t[3] = int(substr($index, 3, 2)) * 7 +
  } elsif ($index =~ /h/) {
      $t[4] = int(substr($index, 2, 2)) -
      $t[3] = int(substr($index, 4, 2
      $t[2] = int(substr($index, 7, 2
  } else {
      $t[2] =
      $t[3] = int(substr($index, 4, 2
      $t[4] = int(substr($index, 2, 2)) -
  }

  return mktimegm(@
}


sub time2index
{
my($type, $prefix, $t) =

    my @t = gmtime($
    if ($type eq "hourly") {
        return sprintf("${PREFIX}${prefix}%02d%02d%02dh%02d", $t[5] % 100, $t[4]+1, $t[3], $t[2
    }

    if ($type =~ /^hourly([23468])$/) {
        my $n = int($
        return sprintf("${PREFIX}${prefix}%02d%02d%02dh%02d", $t[5] % 100, $t[4]+1, $t[3], int($t[2]/$n)*$
    }

    if ($type eq "hourly12") {
        return sprintf("${PREFIX}${prefix}%02d%02d%02dh%02d", $t[5] % 100, $t[4]+1, $t[3], int($t[2]/12)*1
    }

    if ($type eq "daily") {
        return sprintf("${PREFIX}${prefix}%02d%02d%02d", $t[5] % 100, $t[4]+1, $t[3
    }

    if ($type eq "weekly") {
        return sprintf("${PREFIX}${prefix}%02dw%02d", $t[5] % 100, int($t[7]/7
    }

    if ($type eq "monthly") {
        return sprintf("${PREFIX}${prefix}%02dm%02d", $t[5] % 100, $t[4]+
    }
}


sub dbESVersion {
    my $esversion = esGet("/
    my @parts = split(/\./, $esversion->{version}->{number
    $main::esVersion = int($parts[0]*100*100) + int($parts[1]*100) + int($parts[2
    return $esversi
}

sub dbVersion {
my ($loud) =
    my $versi

    $version = esGet("/_template/${PREFIX}sessions2_template?filter_path=**._meta&include_type_name=true",

    if (defined $version &&
        exists $version->{"${PREFIX}sessions2_template"} &&
        exists $version->{"${PREFIX}sessions2_template"}->{mappings}->{session} &&
        exists $version->{"${PREFIX}sessions2_template"}->{mappings}->{session}->{_meta} &&
        exists $version->{"${PREFIX}sessions2_template"}->{mappings}->{session}->{_meta}->{molochDbVersion}
    ) {
        $main::versionNumber = $version->{"${PREFIX}sessions2_template"}->{mappings}->{session}->{_meta}->{molochDbVersio
        retu
    }

    my $version = esGet("/${PREFIX}dstats/version/version",

    my $found = $version->{foun

    if (!defined $found) {
        logmsg "This is a fresh Moloch install\n" if ($lou
        $main::versionNumber =
        if ($loud && $ARGV[1] !~ "init") {
            die "Looks like moloch wasn't installed, must do init"
        }
    } elsif ($found == 0) {
        $main::versionNumber =
    } else {
        $main::versionNumber = $version->{_source}->{versio
    }
}

sub dbCheckForActivity {
    logmsg "This upgrade requires all capture nodes to be stopped.  Checking\
    my $json1 = esGet("/${PREFIX}stats/stat/_search?size=1000
    sleep(
    my $json2 = esGet("/${PREFIX}stats/stat/_search?size=1000
    die "Some capture nodes still active" if ($json1->{hits}->{total} != $json2->{hits}->{total
    return if ($json1->{hits}->{total} ==

    my @hits1 = sort {$a->{_source}->{nodeName} cmp $b->{_source}->{nodeName}} @{$json1->{hits}->{hits
    my @hits2 = sort {$a->{_source}->{nodeName} cmp $b->{_source}->{nodeName}} @{$json2->{hits}->{hits

    for (my $i = $i < $json1->{hits}->{tota $i++) {
        if ($hits1[$i]->{_source}->{nodeName} ne $hits2[$i]->{_source}->{nodeName}) {
            die "Capture node '" . $hits1[$i]->{_source}->{nodeName} . "' or '" . $hits2[$i]->{_source}->{nodeName} . "' still activ
        }

        if ($hits1[$i]->{_source}->{currentTime} != $hits2[$i]->{_source}->{currentTime}) {
            die "Capture node '" . $hits1[$i]->{_source}->{nodeName} . "' still activ
        }
    }
}

sub dbCheckHealth {
    my $health = esGet("/_cluster/health
    if ($health->{status} ne "green") {
        logmsg("WARNING elasticsearch health is '$health->{status}' instead of 'green', things may be broken\n\n
    }
    return $heal
}

sub dbCheck {
    my $esversion = dbESVersion
    my @parts = split(/\./, $esversion->{version}->{number
    $main::esVersion = int($parts[0]*100*100) + int($parts[1]*100) + int($parts[2

    if ($main::esVersion < 60800 || ($main::esVersion >= 70000 && $main::esVersion < 70100)) {
        logmsg("Currently using Elasticsearch version ", $esversion->{version}->{number}, " which isn't supported\n",
              "* < 6.8.0 is not supported\n",
              "* 7.0.x is not supported\n",
              "\n",
              "Instructions: https://molo.ch/faqhow-do-i-upgrade-elasticsearch\n",
              "Make sure to restart any viewer or capture after upgrading!\n"

        exit (1)
    }

    if ($main::esVersion < 60805) {
        logmsg("Currently using Elasticsearch version ", $esversion->{version}->{number}, " 6.8.5 or newer is recommended\n
    }

    my $error =
    my $nodes = esGet("/_nodes?flat_settings
    my $nodeStats = esGet("/_nodes/stats

    foreach my $key (sort {$nodes->{nodes}->{$a}->{name} cmp $nodes->{nodes}->{$b}->{name}} keys %{$nodes->{nodes}}) {
        next if (exists $nodes->{$key}->{attributes} && exists $nodes->{$key}->{attributes}->{data} && $nodes->{$key}->{attributes}->{data} eq "false
        my $node = $nodes->{nodes}->{$ke
        my $nodeStat = $nodeStats->{nodes}->{$ke
        my $errs
        my $warns

        if (exists $node->{settings}->{"index.cache.field.type"}) {
            $errstr .= sprintf ("    REMOVE 'index.cache.field.type'\n
        }

        if (!(exists $nodeStat->{process}->{max_file_descriptors}) || int($nodeStat->{process}->{max_file_descriptors}) < 4000) {
            $errstr .= sprintf ("  INCREASE max file descriptors in /etc/security/limits.conf and restart all ES node\n
            $errstr .= sprintf ("                (change root to the user that runs ES)\n
            $errstr .= sprintf ("          root hard nofile 128000\n
            $errstr .= sprintf ("          root soft nofile 128000\n
        }

        if ($errstr) {
            $error =
            logmsg ("\nERROR: On node ", $node->{name}, " machine ", ($node->{hostname} || $node->{host}), " in file ", $node->{settings}->{config}, "\n
            logmsg($errst
        }

        if ($warnstr) {
            logmsg ("\nWARNING: On node ", $node->{name}, " machine ", ($node->{hostname} || $node->{host}), " in file ", $node->{settings}->{config}, "\n
            logmsg($warnst
        }
    }

    if ($error) {
        logmsg "\nFix above errors before proceeding\
        exit (
    }
}

sub checkForOld2Indices {
    my $result = esGet("/_all/_settings/index.version.created?pretty
    my $found =

    while ( my ($key, $value) = each (%{$result})) {
        if ($value->{settings}->{index}->{version}->{created} < 2000000) {
            logmsg "WARNING: You must delete index '$key' before upgrading to ES 5\
            $found =
        }
    }

    if ($found) {
        logmsg "\nYou MUST delete (and optionally re-add) the indices above while still on ES 2.x otherwise ES 5.x will NOT start.\n\
    }
}

sub checkForOld5Indices {
    my $result = esGet("/_all/_settings/index.version.created?pretty
    my $found =

    while ( my ($key, $value) = each (%{$result})) {
        if ($value->{settings}->{index}->{version}->{created} < 5000000) {
            logmsg "WARNING: You must delete index '$key' before upgrading to ES 6\
            $found =
        }
    }

    if ($found) {
        logmsg "\nYou MUST delete (and optionally re-add) the indices above while still on ES 5.x otherwise ES 6.x will NOT start.\n\
    }
}

sub checkForOld6Indices {
    my $result = esGet("/_all/_settings/index.version.created?pretty
    my $found =

    while ( my ($key, $value) = each (%{$result})) {
        if ($value->{settings}->{index}->{version}->{created} < 6000000) {
            logmsg "WARNING: You must delete index '$key' before upgrading to ES 7\
            $found =
        }
    }

    if ($found) {
        logmsg "\nYou MUST delete (and optionally re-add) the indices above while still on ES 6.x otherwise ES 7.x will NOT start.\n\
    }
}

sub progress {
    my ($msg) =
    if ($verbose == 1) {
        local $| =
        logmsg "
    } elsif ($verbose == 2) {
        local $| =
        logmsg "$ms
    }
}

sub optimizeOther {
    logmsg "Optimizing Admin Indices\
    esForceMerge("${PREFIX}stats_v4,${PREFIX}dstats_v4,${PREFIX}fields_v3,${PREFIX}files_v6,${PREFIX}sequence_v3,${PREFIX}users_v7,${PREFIX}queries_v3,${PREFIX}hunts_v2,${PREFIX}lookups_v1", 1,
    logmsg "\n" if ($verbose >
}

sub parseArgs {
    my ($pos) =

    for$pos <= $AR $pos++) {
        if ($ARGV[$pos] eq "--shards") {
            $pos
            $SHARDS = $ARGV[$po
        } elsif ($ARGV[$pos] eq "--replicas") {
            $pos
            $REPLICAS = int($ARGV[$pos
        } elsif ($ARGV[$pos] eq "--refresh") {
            $pos
            $REFRESH = int($ARGV[$pos
        } elsif ($ARGV[$pos] eq "--history") {
            $pos
            $HISTORY = int($ARGV[$pos
        } elsif ($ARGV[$pos] eq "--segments") {
            $pos
            $SEGMENTS = int($ARGV[$pos
        } elsif ($ARGV[$pos] eq "--segmentsmin") {
            $pos
            $SEGMENTSMIN = int($ARGV[$pos
        } elsif ($ARGV[$pos] eq "--nooptimize") {
            $NOOPTIMIZE =
        } elsif ($ARGV[$pos] eq "--full") {
            $FULL =
        } elsif ($ARGV[$pos] eq "--reverse") {
            $REVERSE =
        } elsif ($ARGV[$pos] eq "--skipupgradeall") {
            $UPGRADEALLSESSIONS =
        } elsif ($ARGV[$pos] eq "--shardsPerNode") {
            $pos
            if ($ARGV[$pos] eq "null") {
                $SHARDSPERNODE = "nul
            } else {
                $SHARDSPERNODE = int($ARGV[$pos
            }
        } elsif ($ARGV[$pos] eq "--hotwarm") {
            $DOHOTWARM =
        } elsif ($ARGV[$pos] eq "--ilm") {
            $DOILM =
        } elsif ($ARGV[$pos] eq "--warmafter") {
            $pos
            $WARMAFTER = int($ARGV[$pos
            $WARMKIND = $ARGV[
            if (substr($ARGV[$pos], -6) eq "hourly") {
                $WARMKIND = "hourl
            } elsif (substr($ARGV[$pos], -5) eq "daily") {
                $WARMKIND = "dail
            }
        } elsif ($ARGV[$pos] eq "--optimizewarm") {
            $OPTIMIZEWARM =
        } elsif ($ARGV[$pos] eq "--shared") {
            $SHARED =
        } elsif ($ARGV[$pos] eq "--locked") {
            $LOCKED =
        } elsif ($ARGV[$pos] eq "--gz") {
            $GZ =
        } elsif ($ARGV[$pos] eq "--type") {
            $pos
            $TYPE = $ARGV[$po
        } elsif ($ARGV[$pos] eq "--description") {
            $pos
            $DESCRIPTION = $ARGV[$po
        } else {
            logmsg "Unknown option '$ARGV[$pos]'\
        }
    }
}

while (@ARGV > 0 && substr($ARGV[0], 0, 1) eq "-") {
    if ($ARGV[0] =~ /(-v+|--verbose)$/) {
         $verbose += ($ARGV[0] =~ tr/v/
    } elsif ($ARGV[0] =~ /--prefix$/) {
        $PREFIX = $ARGV[
        shift @AR
        $PREFIX .= "_" if ($PREFIX !~ /_$
    } elsif ($ARGV[0] =~ /-n$/) {
        $NOCHANGES =
    } elsif ($ARGV[0] =~ /--insecure$/) {
        $SECURE =
    } elsif ($ARGV[0] =~ /--clientcert$/) {
        $CLIENTCERT = $ARGV[
        shift @AR
    } elsif ($ARGV[0] =~ /--clientkey$/) {
        $CLIENTKEY = $ARGV[
        shift @AR
    } elsif ($ARGV[0] =~ /--timeout$/) {
        $ESTIMEOUT = int($ARGV[1
        shift @AR
    } else {
        showHelp("Unknkown global option $ARGV[0]")
    }
    shift @AR
}

showHelp("Help:") if ($ARGV[1] =~ /^help$
showHelp("Missing arguments") if (@ARGV <
showHelp("Unknown command '$ARGV[1]'") if ($ARGV[1] !~ /^(init|initnoprompt|clean|info|wipe|upgrade|upgradenoprompt|disable-?users|set-?shortcut|users-?import|import|restore|users-?export|export|backup|expire|rotate|optimize|optimize-admin|mv|rm|rm-?missing|rm-?node|add-?missing|field|force-?put-?version|sync-?files|hide-?node|unhide-?node|add-?alias|set-?replicas|set-?shards-?per-?node|set-?allocation-?enable|allocate-?empty|unflood-?stage|shrink|ilm)$
showHelp("Missing arguments") if (@ARGV < 3 && $ARGV[1] =~ /^(users-?import|import|users-?export|backup|restore|rm|rm-?missing|rm-?node|hide-?node|unhide-?node|set-?allocation-?enable|unflood-?stage)$
showHelp("Missing arguments") if (@ARGV < 4 && $ARGV[1] =~ /^(field|export|add-?missing|sync-?files|add-?alias|set-?replicas|set-?shards-?per-?node|set-?shortcut|ilm)$
showHelp("Missing arguments") if (@ARGV < 5 && $ARGV[1] =~ /^(allocate-?empty|set-?shortcut|shrink)$
showHelp("Must have both <old fn> and <new fn>") if (@ARGV < 4 && $ARGV[1] =~ /^(mv)$
showHelp("Must have both <type> and <num> arguments") if (@ARGV < 4 && $ARGV[1] =~ /^(rotate|expire)$

parseArgs(2) if ($ARGV[1] =~ /^(init|initnoprompt|upgrade|upgradenoprompt|clean)$
parseArgs(3) if ($ARGV[1] =~ /^(restore)$

$ESTIMEOUT = 240 if ($ESTIMEOUT < 240 && $ARGV[1] =~ /^(init|initnoprompt|upgrade|upgradenoprompt|clean|shrink|ilm)$

$main::userAgent = LWP::UserAgent->new(timeout => $ESTIMEOUT + 5, keep_alive =>
if ($CLIENTCERT ne "") {
    $main::userAgent->ssl_opts(
        SSL_verify_mode => $SECURE,
        verify_hostname=> $SECURE,
        SSL_cert_file => $CLIENTCERT,
        SSL_key_file => $CLIENTKEY
    )
} else {
    $main::userAgent->ssl_opts(
        SSL_verify_mode => $SECURE,
        verify_hostname=> $SECURE
    )
}

if ($ARGV[0] =~ /^http/) {
    $main::elasticsearch = $ARGV[
} else {
    $main::elasticsearch = "http://$ARGV[0
}

if ($ARGV[1] =~ /^(users-?import|import)$/) {
    open(my $fh, "<", $ARGV[2]) or die "cannot open < $ARGV[2]: $
    my $data = do { local  <$fh>
    esPost("/_bulk", $dat
    close($f
    exit
} elsif ($ARGV[1] =~ /^export$/) {
    my $index = $ARGV[
    my $data = esScroll($index, "", '{"version": true}
    if (scalar(@{$data}) == 0){
        logmsg "The index is empty\
        exit
    }
    open(my $fh, ">", "$ARGV[3].${PREFIX}${index}.json") or die "cannot open > $ARGV[3].${PREFIX}${index}.json: $
    foreach my $hit (@{$data}) {
        print $fh "{\"index\": {\"_index\": \"${PREFIX}${index}\", \"_type\": \"$hit->{_type}\", \"_id\": \"$hit->{_id}\", \"_version\": $hit->{_version}, \"_version_type\": \"external\"}}\
        if (exists $hit->{_source}) {
            print $fh to_json($hit->{_source}) . "\
        } else {
            print $fh "{}\
        }
    }
    close($f
    exit
} elsif ($ARGV[1] =~ /^backup$/) {
    parseArgs(

    sub bopen {
        my ($index) =
        if ($GZ) {
            return new IO::Compress::Gzip "$ARGV[2].${PREFIX}${index}.json.gz" or die "cannot open $ARGV[2].${PREFIX}${index}.json.gz: $GzipError\
        } else {
            open(my $fh, ">", "$ARGV[2].${PREFIX}${index}.json") or die "cannot open > $ARGV[2].${PREFIX}${index}.json: $
            return $
        }
    }

    my @indexes = ("users", "sequence", "stats", "queries", "files", "fields", "dstats
    push(@indexes, "hunts") if ($main::versionNumber > 5
    push(@indexes, "lookups") if ($main::versionNumber > 6
    logmsg "Exporting documents...\
    foreach my $index (@indexes) {
        my $data = esScroll($index, "", '{"version": true}
        next if (scalar(@{$data}) ==
        my $fh = bopen($inde
        foreach my $hit (@{$data}) {
            print $fh "{\"index\": {\"_index\": \"${PREFIX}${index}\", \"_type\": \"$hit->{_type}\", \"_id\": \"$hit->{_id}\", \"_version\": $hit->{_version}, \"_version_type\": \"external\"}}\
            if (exists $hit->{_source}) {
                print $fh to_json($hit->{_source}) . "\
            } else {
                print $fh "{}\
            }
        }
        close($f
    }
    logmsg "Exporting templates...\
    my @templates = ("sessions2_template", "history_v1_template
    foreach my $template (@templates) {
        my $data = esGet("/_template/${PREFIX}${template}?include_type_name=true
        my @name = split(/_/, $templat
        my $fh = bopen("template
        print $fh to_json($dat
        close($f
    }
    logmsg "Exporting settings...\
    foreach my $index (@indexes) {
        my $data = esGet("/${PREFIX}${index}/_settings
        my $fh = bopen("${index}.settings
        print $fh to_json($dat
        close($f
    }
    logmsg "Exporting mappings...\
    foreach my $index (@indexes) {
        my $data = esGet("/${PREFIX}${index}/_mappings
        my $fh = bopen("${index}.mappings
        print $fh to_json($dat
        close($f
    }
    logmsg "Exporting aliaes...\

    my @indexes_prefixed =
    foreach my $index (@indexes) {
        push(@indexes_prefixed, $PREFIX . $inde
    }
    my $aliases = join(',', @indexes_prefixe
    $aliases = "/_cat/aliases/${aliases}?format=jso
    my $data = esGet($aliases), "\
    my $fh = bopen("aliases
    print $fh to_json($dat
    close($f
    logmsg "Finished\
    exit
} elsif ($ARGV[1] =~ /^users-?export$/) {
    open(my $fh, ">", $ARGV[2]) or die "cannot open > $ARGV[2]: $
    my $users = esGet("/${PREFIX}users/_search?size=1000
    foreach my $hit (@{$users->{hits}->{hits}}) {
        print $fh "{\"index\": {\"_index\": \"users\", \"_type\": \"user\", \"_id\": \"" . $hit->{_id} . "\"}}\
        print $fh to_json($hit->{_source}) . "\
    }
    close($f
    exit
} elsif ($ARGV[1] =~ /^(rotate|expire)$/) {
    showHelp("Invalid expire <type>") if ($ARGV[2] !~ /^(hourly|hourly[23468]|hourly12|daily|weekly|monthly)$

    $SEGMENTSMIN = $SEGMENTS if ($SEGMENTSMIN == -

     First handle sessions expire
    my $indicesa = esGet("/_cat/indices/${PREFIX}sessions2*?format=json",
    my %indices = map { $_->{index} => $_ } @{$indices

    my $endTime = time
    my $endTimeIndex = time2index($ARGV[2], "sessions2-", $endTim
    delete $indices{$endTimeInde  Don't optimize current index

    my @startTime = kind2time($ARGV[2], int($ARGV[3]

    parseArgs(

    my $startTime = mktimegm(@startTim
    my @warmTime = kind2time($WARMKIND, $WARMAFTE
    my $warmTime = mktimegm(@warmTim
    my $optimizecnt =
    my $warmcnt =
    my @indiceskeys = sort (keys %indice

    foreach my $i (@indiceskeys) {
        my $t = index2time($
        if ($t >= $startTime) {
            $indices{$i}->{OPTIMIZEIT} =
            $optimizecnt
        }
        if ($WARMAFTER != -1 && $t < $warmTime) {
            $indices{$i}->{WARMIT} =
            $warmcnt
        }
    }

    my $nodes = esGet("/_nodes
    $main::numberOfNodes = dataNodes($nodes->{nodes
    my $shardsPerNode = ceil($SHARDS * ($REPLICAS+1) / $main::numberOfNode
    $shardsPerNode = $SHARDSPERNODE if ($SHARDSPERNODE eq "null" || $SHARDSPERNODE > $shardsPerNod

    dbESVersion
    optimizeOther() unless $NOOPTIMIZ
    logmsg sprintf ("Expiring %s sessions indices, %s optimizing %s, warming %s\n", commify(scalar(keys %indices) - $optimizecnt), $NOOPTIMIZE?"Not":"", commify($optimizecnt), commify($warmcnt
    esPost("/_flush/synced", "",

    @indiceskeys = reverse(@indiceskeys) if ($REVERS

     Get all the settings at once, we use below to see if we need to change them
    my $settings = esGet("/_settings?flat_settings&master_timeout=${ESTIMEOUT}s",

     Find all the shards that have too many segments and increment the OPTIMIZEIT count or not warm
    my $shards = esGet("/_cat/shards/${PREFIX}sessions2*?h=i,sc&format=json
    for my $i (@{$shards}) {
         Not expiring and too many segments
        if (exists $indices{$i->{i}}->{OPTIMIZEIT} && defined $i->{sc} && int($i->{sc}) > $SEGMENTSMIN) {
             Either not only optimizing warm or make sure we are green warm
            if (!$OPTIMIZEWARM ||
                ($settings->{$i->{i}}->{settings}->{"index.routing.allocation.require.molochtype"} eq "warm" && $indices{$i->{i}}->{health} eq "green")) {

                $indices{$i->{i}}->{OPTIMIZEIT}
            }
        }

        if (exists $indices{$i->{i}}->{WARMIT} && $settings->{$i->{i}}->{settings}->{"index.routing.allocation.require.molochtype"} ne "warm") {
            $indices{$i->{i}}->{WARMIT}
        }
    }

    foreach my $i (@indiceskeys) {
        progress("$i
        if (exists $indices{$i}->{OPTIMIZEIT}) {

             1 is set if it shouldn't be expired, > 1 means it needs to be optimized
            if ($indices{$i}->{OPTIMIZEIT} > 1) {
                esForceMerge($i, $SEGMENTS, 1) unless $NOOPTIMI
            }

            if ($REPLICAS != -1) {
                if (!exists $settings->{$i} ||
                    $settings->{$i}->{settings}->{"index.number_of_replicas"} ne "$REPLICAS" ||
                    ("$shardsPerNode" eq "null" && exists $settings->{$i}->{settings}->{"index.routing.allocation.total_shards_per_node"}) ||
                    ("$shardsPerNode" ne "null" && $settings->{$i}->{settings}->{"index.routing.allocation.total_shards_per_node"} ne "$shardsPerNode")) {

                    esPut("/$i/_settings?master_timeout=${ESTIMEOUT}s", '{"index": {"number_of_replicas":' . $REPLICAS . ', "routing.allocation.total_shards_per_node": ' . $shardsPerNode . '}}',
                }
            }
        } else {
            esDelete("/$i",
        }

        if ($indices{$i}->{WARMIT} > 1) {
            esPut("/$i/_settings?master_timeout=${ESTIMEOUT}s", '{"index": {"routing.allocation.require.molochtype": "warm"}}',
        }
    }
    esPost("/_flush/synced", "",

     Now figure out history expire
    my $hindices = esGet("/${PREFIX}history_v1-*/_alias",

    $endTimeIndex = time2index("weekly", "history_v1-", $endTim
    delete $hindices->{$endTimeInde

    @startTime = gmti
    $startTime[3] -= 7 * $HISTO

    $optimizecnt =
    $startTime = mktimegm(@startTim
    while ($startTime <= $endTime) {
        my $iname = time2index("weekly", "history_v1-", $startTim
        if (exists $hindices->{$iname} && $hindices->{$iname}->{OPTIMIZEIT} != 1) {
            $hindices->{$iname}->{OPTIMIZEIT} =
            $optimizecnt
        } elsif (exists $hindices->{"$iname-shrink"} && $hindices->{"$iname-shrink"}->{OPTIMIZEIT} != 1) {
            $hindices->{"$iname-shrink"}->{OPTIMIZEIT} =
            $optimizecnt
        }
        $startTime += 24*60*
    }

    logmsg sprintf ("Expiring %s history indices, %s optimizing %s\n", commify(scalar(keys %{$hindices}) - $optimizecnt), $NOOPTIMIZE?"Not":"", commify($optimizecnt
    foreach my $i (sort (keys %{$hindices})) {
        progress("$i
        if (! exists $hindices->{$i}->{OPTIMIZEIT}) {
            esDelete("/$i",
        }
    }
    esForceMerge("${PREFIX}history_*", 1, 1) unless $NOOPTIMI
    esPost("/_flush/synced", "",

     Give the cluster a kick to rebalance
    esPost("/_cluster/reroute?master_timeout=${ESTIMEOUT}s&retry_failed
    exit
} elsif ($ARGV[1] eq "optimize") {
    my $indices = esGet("/${PREFIX}sessions2-*/_alias",

    dbESVersion
    $main::userAgent->timeout(720
    esPost("/_flush/synced", "",
    optimizeOther
    logmsg sprintf "Optimizing %s Session Indices\n", commify(scalar(keys %{$indices}
    foreach my $i (sort (keys %{$indices})) {
        progress("$i
        esForceMerge($i, $SEGMENTS,
    }
    esPost("/_flush/synced", "",
    logmsg "Optimizing History\
    esForceMerge("${PREFIX}history_v1-*", 1,
    logmsg "\
    exit
} elsif ($ARGV[1] eq "optimize-admin") {
    $main::userAgent->timeout(720
    esPost("/_flush/synced", "",
    optimizeOther
    esForceMerge("${PREFIX}history_*", 1,
    exit
} elsif ($ARGV[1] =~ /^(disable-?users)$/) {
    showHelp("Invalid number of <days>") if (!defined $ARGV[2] || $ARGV[2] !~ /^[+-]?\d+$

    my $users = esGet("/${PREFIX}users/_search?size=1000&q=enabled:true+AND+createEnabled:false+AND+_exists_:lastUsed
    my $rmcount =

    foreach my $hit (@{$users->{hits}->{hits}}) {
        my $epoc = time
        my $lastUsed = $hit->{_source}->{lastUse
        $lastUsed = $lastUsed / 10   convert to seconds
        $lastUsed = $epoc - $lastUs  in seconds
        $lastUsed = $lastUsed / 864  days since last used
        if ($lastUsed > $ARGV[2]) {
            my $userId = $hit->{_source}->{userI
            print "Disabling user: $userId\
            esPost("/${PREFIX}users/user/$userId/_update", '{"doc": {"enabled": false}}
            $rmcount
        }
    }

    if ($rmcount == 0) {
      print "No users disabled\
    } else {
      print "$rmcount user(s) disabled\
    }

    exit
} elsif ($ARGV[1] =~ /^(set-?shortcut)$/) {
    showHelp("Invalid name $ARGV[2], names cannot have special characters except '_'") if ($ARGV[2] =~ /[^-a-zA-Z0-9_]$
    showHelp("file '$ARGV[4]' not found") if (! -e $ARGV[4
    showHelp("file '$ARGV[4]' empty") if (-z $ARGV[4

    parseArgs(

    showHelp("Type must be ip, string, or number instead of $TYPE") if ($TYPE !~ /^(string|ip|number)$

     read shortcuts file
    my $shortcutValu
    open(my $fh, '<', $ARGV[4
    {
      local
      $shortcutValues = <$f
    }
    close($f

    my $shortcutsArray = [split /[\n,]/, $shortcutValue

    my $shortcutName = $ARGV[
    my $shortcutUserId = $ARGV[

    my $shortcuts = esGet("/${PREFIX}lookups/_search?q=name:${shortcutName}

    my $existingShortc
    foreach my $shortcut (@{$shortcuts->{hits}->{hits}}) {
      if ($shortcut->{_source}->{name} == $shortcutName) {
        $existingShortcut = $shortc
        la
      }
    }

     create shortcut object
    my $newShortc
    $newShortcut->{name} = $shortcutNa
    $newShortcut->{userId} = $shortcutUser
    $newShortcut->{$TYPE} = $shortcutsArr
    if ($existingShortcut) {  use existing optional fields
      if ($existingShortcut->{_source}->{description}) {
        $newShortcut->{description} = $existingShortcut->{_source}->{descriptio
      }
      if ($existingShortcut->{_source}->{shared}) {
        $newShortcut->{shared} = $existingShortcut->{_source}->{share
      }
    }
    if ($DESCRIPTION) {
      $newShortcut->{description} = $DESCRIPTI
    }
    if ($SHARED) {
      $newShortcut->{shared} =
    }
    if ($LOCKED) {
      $newShortcut->{locked} =
    }

    my $verb = "Create
    if ($existingShortcut) {  update the shortcut
      $verb = "Update
      my $id = $existingShortcut->{_i
      esPost("/${PREFIX}lookups/lookup/${id}", to_json($newShortcut
    } else {  create the shortcut
      esPost("/${PREFIX}lookups/lookup", to_json($newShortcut
    }

    print "${verb} shortcut ${shortcutName}\

    exit
} elsif ($ARGV[1] =~ /^(shrink)$/) {
    parseArgs(
    die "Only shrink history and sessions2 indices" if ($ARGV[2] !~ /(sessions2|history)

    logmsg("Moving all shards for ${PREFIX}$ARGV[2] to $ARGV[3]\n
    my $json = esPut("/${PREFIX}$ARGV[2]/_settings?master_timeout=${ESTIMEOUT}s", "{\"settings\": {\"index.routing.allocation.total_shards_per_node\": null, \"index.routing.allocation.require._name\" : \"$ARGV[3]\", \"index.blocks.write\": true}}

    while (1) {
      $json = esGet("/_cluster/health?wait_for_no_relocating_shards=true&timeout=30s",
      last if ($json->{relocating_shards} ==
      progress("Waiting for relocation to finish\n
    }
    logmsg("Shrinking ${PREFIX}$ARGV[2] to ${PREFIX}$ARGV[2]-shrink\n
    $json = esPut("/${PREFIX}$ARGV[2]/_shrink/${PREFIX}$ARGV[2]-shrink?master_timeout=${ESTIMEOUT}s&copy_settings=true", '{"settings": {"index.routing.allocation.require._name": null, "index.blocks.write": null, "index.codec": "best_compression", "index.number_of_shards": ' . $ARGV[4] . '}}

    logmsg("Checking for completion\n
    my $status = esGet("/${PREFIX}$ARGV[2]-shrink/_refresh",
    my $status = esGet("/${PREFIX}$ARGV[2]-shrink/_flush",
    my $status = esGet("/_stats/docs",
    if ($status->{indices}->{"${PREFIX}$ARGV[2]-shrink"}->{primaries}->{docs}->{count} == $status->{indices}->{"${PREFIX}$ARGV[2]"}->{primaries}->{docs}->{count}) {
        logmsg("Deleting old index\n
        esDelete("/${PREFIX}$ARGV[2]",
        esPut("/${PREFIX}$ARGV[2]-shrink/_settings?master_timeout=${ESTIMEOUT}s", "{\"index.routing.allocation.total_shards_per_node\" : $SHARDSPERNODE}") if ($SHARDSPERNODE ne "null
    } else {
        logmsg("Doc counts don't match, not deleting old index\n
    }
    exit
} elsif ($ARGV[1] eq "info") {
    dbVersion(
    my $esversion = dbESVersion
    my $nodes = esGet("/_nodes
    my $status = esGet("/_stats/docs,store",

    my $sessions =
    my $sessionsBytes =
    my @sessions = grep /^${PREFIX}sessions2-/, keys %{$status->{indices
    foreach my $index (@sessions) {
        next if ($index !~ /^${PREFIX}sessions2-
        $sessions += $status->{indices}->{$index}->{primaries}->{docs}->{coun
        $sessionsBytes += $status->{indices}->{$index}->{primaries}->{store}->{size_in_byte
    }

    my $historys =
    my $historysBytes =
    my @historys = grep /^${PREFIX}history_v1-/, keys %{$status->{indices
    foreach my $index (@historys) {
        next if ($index !~ /^${PREFIX}history_v1-
        $historys += $status->{indices}->{$index}->{primaries}->{docs}->{coun
        $historysBytes += $status->{indices}->{$index}->{primaries}->{store}->{size_in_byte
    }

    sub printIndex {
        my ($status, $name) =
        my $index = $status->{indices}->{$PREFIX.$nam
        return if (!$inde
        printf "%-20s %17s (%s bytes)\n", $name . ":", commify($index->{primaries}->{docs}->{count}), commify($index->{primaries}->{store}->{size_in_bytes
    }

    printf "Cluster Name:        %17s\n", $esversion->{cluster_nam
    printf "ES Version:          %17s\n", $esversion->{version}->{numbe
    printf "DB Version:          %17s\n", $main::versionNumb
    printf "ES Nodes:            %17s/%s\n", commify(dataNodes($nodes->{nodes})), commify(scalar(keys %{$nodes->{nodes}}
    printf "Session Indices:     %17s\n", commify(scalar(@sessions
    printf "Sessions2:           %17s (%s bytes)\n", commify($sessions), commify($sessionsByte
    if (scalar(@sessions) > 0) {
        printf "Session Density:     %17s (%s bytes)\n", commify(int($sessions/(scalar(keys %{$nodes->{nodes}})*scalar(@sessions)))),
                                                       commify(int($sessionsBytes/(scalar(keys %{$nodes->{nodes}})*scalar(@sessions))
    }
    printf "History Indices:     %17s\n", commify(scalar(@historys
    printf "Histories:           %17s (%s bytes)\n", commify($historys), commify($historysByte
    if (scalar(@historys) > 0) {
        printf "History Density:     %17s (%s bytes)\n", commify(int($historys/(scalar(keys %{$nodes->{nodes}})*scalar(@historys)))),
                                                       commify(int($historysBytes/(scalar(keys %{$nodes->{nodes}})*scalar(@historys))
    }
    printIndex($status, "stats_v4
    printIndex($status, "stats_v3
    printIndex($status, "fields_v3
    printIndex($status, "fields_v2
    printIndex($status, "files_v6
    printIndex($status, "files_v5
    printIndex($status, "users_v7
    printIndex($status, "users_v6
    printIndex($status, "users_v5
    printIndex($status, "users_v4
    printIndex($status, "hunts_v2
    printIndex($status, "hunts_v1
    printIndex($status, "dstats_v4
    printIndex($status, "dstats_v3
    printIndex($status, "sequence_v3
    printIndex($status, "sequence_v2
    exit
} elsif ($ARGV[1] eq "mv") {
    (my $fn = $ARGV[2]) =~ s/\//\\\/
    my $results = esGet("/${PREFIX}files/_search?q=name:$fn
    die "Couldn't find '$ARGV[2]' in db\n" if (@{$results->{hits}->{hits}} ==

    foreach my $hit (@{$results->{hits}->{hits}}) {
        my $script = '{"script" : "ctx._source.name = \"' . $ARGV[3] . ' ctx._source.locked ="
        esPost("/${PREFIX}files/file/" . $hit->{_id} . "/_update", $scrip
    }
    logmsg "Moved " . scalar (@{$results->{hits}->{hits}}) . " file(s) in database\
    exit
} elsif ($ARGV[1] eq "rm") {
    (my $fn = $ARGV[2]) =~ s/\//\\\/
    my $results = esGet("/${PREFIX}files/_search?q=name:$fn
    die "Couldn't find '$ARGV[2]' in db\n" if (@{$results->{hits}->{hits}} ==

    foreach my $hit (@{$results->{hits}->{hits}}) {
        esDelete("/${PREFIX}files/file/" . $hit->{_id},
    }
    logmsg "Removed " . scalar (@{$results->{hits}->{hits}}) . " file(s) in database\
    exit
} elsif ($ARGV[1] =~ /^rm-?missing$/) {
    my $results = esGet("/${PREFIX}files/_search?size=10000&q=node:$ARGV[2]
    die "Couldn't find '$ARGV[2]' in db\n" if (@{$results->{hits}->{hits}} ==
    logmsg "Need to remove references to these files from database:\
    my $cnt =
    foreach my $hit (@{$results->{hits}->{hits}}) {
        if (! -f $hit->{_source}->{name}) {
            logmsg $hit->{_source}->{name}, "\
            $cnt
        }
    }
    die "Nothing found to remove." if ($cnt ==
    logmsg "\
    waitFor("YES", "Do you want to remove file references from database?
    foreach my $hit (@{$results->{hits}->{hits}}) {
        if (! -f $hit->{_source}->{name}) {
            esDelete("/${PREFIX}files/file/" . $hit->{_id},
        }
    }
    exit
} elsif ($ARGV[1] =~ /^rm-?node$/) {
    my $results = esGet("/${PREFIX}files/_search?size=10000&q=node:$ARGV[2]
    logmsg "Deleting ", $results->{hits}->{total}, " files\
    foreach my $hit (@{$results->{hits}->{hits}}) {
        esDelete("/${PREFIX}files/file/" . $hit->{_id},
    }
    esDelete("/${PREFIX}stats/stat/" . $ARGV[2],
    my $results = esGet("/${PREFIX}dstats/_search?size=10000&q=nodeName:$ARGV[2]
    logmsg "Deleting ", $results->{hits}->{total}, " stats\
    foreach my $hit (@{$results->{hits}->{hits}}) {
        esDelete("/${PREFIX}dstats/dstat/" . $hit->{_id},
    }
    exit
} elsif ($ARGV[1] =~ /^hide-?node$/) {
    my $results = esGet("/${PREFIX}stats/stat/$ARGV[2]",
    die "Node $ARGV[2] not found" if (!$results->{found
    esPost("/${PREFIX}stats/stat/$ARGV[2]/_update", '{"doc": {"hide": true}}
    exit
} elsif ($ARGV[1] =~ /^unhide-?node$/) {
    my $results = esGet("/${PREFIX}stats/stat/$ARGV[2]",
    die "Node $ARGV[2] not found" if (!$results->{found
    esPost("/${PREFIX}stats/stat/$ARGV[2]/_update", '{"script" : "ctx._source.remove(\"hide\")"}
    exit
} elsif ($ARGV[1] =~ /^add-?alias$/) {
    my $results = esGet("/${PREFIX}stats/stat/$ARGV[2]",
    die "Node $ARGV[2] already exists, must remove first" if ($results->{found
    esPost("/${PREFIX}stats/stat/$ARGV[2]", '{"nodeName": "' . $ARGV[2] . '", "hostname": "' . $ARGV[3] . '", "hide": true}
    exit
} elsif ($ARGV[1] =~ /^add-?missing$/) {
    my $dir = $ARGV[
    chop $dir if (substr($dir, -1) eq "/
    opendir(my $dh, $dir) || die "Can't opendir $dir: $
    my @files = grep { m/^$ARGV[2]-/ && -f "$dir/$_" } readdir($d
    closedir $
    logmsg "Checking ", scalar @files, " files, this may take a while.\
    foreach my $file (@files) {
        $file =~ /(\d+)-(\d+).pca
        my $filenum = int($
        my $ctime = (stat("$dir/$file"))[1
        my $info = esGet("/${PREFIX}files/file/$ARGV[2]-$filenum",
        if (!$info->{found}) {
            logmsg "Adding $dir/$file $filenum $ctime\
            esPost("/${PREFIX}files/file/$ARGV[2]-$filenum", to_json({
                         'locked' => 0,
                         'first' => $ctime,
                         'num' => $filenum,
                         'name' => "$dir/$file",
                         'node' => $ARGV[2]}),
        } elsif ($verbose > 0) {
            logmsg "Ok $dir/$file\
        }
    }
    exit
} elsif ($ARGV[1] =~ /^sync-?files$/) {
    my @nodes = split(",", $ARGV[2
    my @dirs = split(",", $ARGV[3

     find all local files, do this first also to make sure we can access dirs
    my @localfiles =
    foreach my $dir (@dirs) {
        chop $dir if (substr($dir, -1) eq "/
        opendir(my $dh, $dir) || die "Can't opendir $dir: $
        foreach my $node (@nodes) {
            my @files = grep { m/^$ARGV[2]-/ && -f "$dir/$_" } readdir($d
            @files = map "$dir/$_", @fil
            push (@localfiles, @file
        }
        closedir $
    }

     See what files are in db
    my $remotefiles = esScroll("files", "file", to_json({'query' => {'terms' => {'node' => \@nodes}}}
    logmsg("\n") if ($verbose >
    my %remotefilesha
    foreach my $hit (@{$remotefiles}) {
        if (! -f $hit->{_source}->{name}) {
            progress("Removing " . $hit->{_source}->{name} . " id: " . $hit->{_id} . "\n
            esDelete("/${PREFIX}files/file/" . $hit->{_id},
        } else {
            $remotefileshash{$hit->{_source}->{name}} = $hit->{_sourc
        }
    }

     Now see which local are missing
    foreach my $file (@localfiles) {
        my @stat = stat("$file
        if (!exists $remotefileshash{$file}) {
            $file =~ /\/([^\/]*)-(\d+)-(\d+).pca
            my $node =
            my $filenum = int($
            progress("Adding $file $node $filenum $stat[7]\n
            esPost("/${PREFIX}files/file/$node-$filenum", to_json({
                         'locked' => 0,
                         'first' => $stat[10],
                         'num' => $filenum,
                         'name' => "$file",
                         'node' => $node,
                         'filesize' => $stat[7]}),
        } elsif ($stat[7] != $remotefileshash{$file}->{filesize}) {
          progress("Updating filesize $file $stat[7]\n
          $file =~ /\/([^\/]*)-(\d+)-(\d+).pca
          my $node =
          my $filenum = int($
          $remotefileshash{$file}->{filesize} = $stat[
          esPost("/${PREFIX}files/file/$node-$filenum", to_json($remotefileshash{$file}),
        }
    }
    logmsg("\n") if ($verbose >
    exit
} elsif ($ARGV[1] =~ /^(field)$/) {
    my $result = esGet("/${PREFIX}fields/field/$ARGV[3]",
    my $found = $result->{foun
    die "Field $ARGV[3] isn't found" if (!$foun

    esPost("/${PREFIX}fields/field/$ARGV[3]/_update", "{\"doc\":{\"disabled\":" . ($ARGV[2] eq "disable"?"true":"false").  "}}
    exit
} elsif ($ARGV[1] =~ /^force-?put-?version$/) {
    die "This command doesn't work anymor
    exit
} elsif ($ARGV[1] =~ /^set-?replicas$/) {
    esPost("/_flush/synced", "",
    esPut("/${PREFIX}$ARGV[2]/_settings?master_timeout=${ESTIMEOUT}s", "{\"index.number_of_replicas\" : $ARGV[3]}
    exit
} elsif ($ARGV[1] =~ /^set-?shards-?per-?node$/) {
    esPost("/_flush/synced", "",
    esPut("/${PREFIX}$ARGV[2]/_settings?master_timeout=${ESTIMEOUT}s", "{\"index.routing.allocation.total_shards_per_node\" : $ARGV[3]}
    exit
} elsif ($ARGV[1] =~ /^set-?allocation-?enable$/) {
    esPost("/_flush/synced", "",
    if ($ARGV[2] eq "null") {
        esPut("/_cluster/settings?master_timeout=${ESTIMEOUT}s", "{ \"persistent\": { \"cluster.routing.allocation.enable\": null}}
    } else {
        esPut("/_cluster/settings?master_timeout=${ESTIMEOUT}s", "{ \"persistent\": { \"cluster.routing.allocation.enable\": \"$ARGV[2]\"}}
    }
    exit
} elsif ($ARGV[1] =~ /^allocate-?empty$/) {
    my $result = esPost("/_cluster/reroute?master_timeout=${ESTIMEOUT}s", "{ \"commands\": [{\"allocate_empty_primary\": {\"index\": \"$ARGV[3]\", \"shard\": \"$ARGV[4]\", \"node\": \"$ARGV[2]\", \"accept_data_loss\": true}}]}
    exit
} elsif ($ARGV[1] =~ /^unflood-?stage$/) {
    esPut("/${PREFIX}$ARGV[2]/_settings?master_timeout=${ESTIMEOUT}s", "{\"index.blocks.read_only_allow_delete\" : null}
    exit
} elsif ($ARGV[1] =~ /^ilm$/) {
    parseArgs(
    my $forceTime = $ARGV[
    die "force time must be num followed by h or d" if ($forceTime !~ /^\d+[hd]
    my $deleteTime = $ARGV[
    die "delete time must be num followed by h or d" if ($deleteTime !~ /^\d+[hd]
    $REPLICAS = 0 if ($REPLICAS == -
    $HISTORY = $HISTORY *

    print "Creating history ilm policy '${PREFIX}molochhistory' with: deleteTime ${HISTORY}d\
    print "Creating sessions ilm policy '${PREFIX}molochsessions' with: forceTime: $forceTime deleteTime: $deleteTime segments: $SEGMENTS replicas: $REPLICAS\
    print "You will need to run db.pl upgrade with --ilm to update the templates the first time you turn ilm on.\
    sleep
    my $hpolicy =
qq/ {
  "policy": {
    "phases": {
      "delete": {
        "min_age": "${HISTORY}d",
        "actions": {
          "delete": {}
        }
      }
    }
  }

    esPut("/_ilm/policy/${PREFIX}molochhistory?master_timeout=${ESTIMEOUT}s", $hpolic
    esPut("/${PREFIX}history_v*/_settings?master_timeout=${ESTIMEOUT}s", qq/{"settings": {"index.lifecycle.name": "${PREFIX}molochhistory"}}/,
    print "History Policy:\n$hpolicy\n" if ($verbose >
    sleep

    my $poli
    if ($DOHOTWARM) {
        $policy =
qq/ {
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "set_priority": {
            "priority": 95
          }
        }
      },
      "warm": {
        "min_age": "$forceTime",
        "actions": {
          "allocate": {
            "number_of_replicas": $REPLICAS,
            "require": {
              "molochtype": "warm"
            }
          },
          "forcemerge": {
            "max_num_segments": $SEGMENTS
          },
          "set_priority": {
            "priority": 10
          }
        }
      },
      "delete": {
        "min_age": "$deleteTime",
        "actions": {
          "delete": {}
        }
      }
    }
  }

    } else {
        $policy =
qq/ {
  "policy": {
    "phases": {
      "warm": {
        "min_age": "$forceTime",
        "actions": {
          "allocate": {
            "number_of_replicas": $REPLICAS
          },
          "forcemerge": {
            "max_num_segments": $SEGMENTS
          },
          "set_priority": {
            "priority": 10
          }
        }
      },
      "delete": {
        "min_age": "$deleteTime",
        "actions": {
          "delete": {}
        }
      }
    }
  }

    }
    esPut("/_ilm/policy/${PREFIX}molochsessions?master_timeout=${ESTIMEOUT}s", $polic
    esPut("/${PREFIX}sessions2-*/_settings?master_timeout=${ESTIMEOUT}s", qq/{"settings": {"index.lifecycle.name": "${PREFIX}molochsessions"}}/,
    print "Policy:\n$policy\n" if ($verbose >
    exit
}

sub dataNodes
{
my ($nodes) =
    my $total =

    foreach my $key (keys %{$nodes}) {
        next if (exists $nodes->{$key}->{attributes} && exists $nodes->{$key}->{attributes}->{data} && $nodes->{$key}->{attributes}->{data} eq "false
        next if (exists $nodes->{$key}->{settings} && exists $nodes->{$key}->{settings}->{node} && $nodes->{$key}->{settings}->{node}->{data} eq "false
        $total
    }
    return $tot
}


my $health = dbCheckHealth

my $nodes = esGet("/_nodes
$main::numberOfNodes = dataNodes($nodes->{nodes
logmsg "It is STRONGLY recommended that you stop ALL moloch captures and viewers before proceeding.  Use 'db.pl ${main::elasticsearch} backup' to backup db first.\n\
if ($main::numberOfNodes == 1) {
    logmsg "There is $main::numberOfNodes elastic search data node, if you expect more please fix first before proceeding.\n\
} else {
    logmsg "There are $main::numberOfNodes elastic search data nodes, if you expect more please fix first before proceeding.\n\
}

if (int($SHARDS) > $main::numberOfNodes) {
    die "Can't set shards ($SHARDS) greater then the number of nodes ($main::numberOfNodes
} elsif ($SHARDS == -1) {
    $SHARDS = $main::numberOfNod
    if ($SHARDS > 24) {
        logmsg "Setting  of shards to 24, use --shards for a different number\
        $SHARDS =
    }
}

dbVersion(

if ($ARGV[1] eq "wipe" && $main::versionNumber != $VERSION) {
    die "Can only use wipe if schema is up to date.  Use upgrade first
}

dbCheck

if ($ARGV[1] =~ /^(init|wipe|clean)/) {

    if ($ARGV[1] eq "init" && $main::versionNumber >= 0) {
        logmsg "It appears this elastic search cluster already has moloch installed (version $main::versionNumber), this will delete ALL data in elastic search! (It does not delete the pcap files on disk.)\n\
        waitFor("INIT", "do you want to erase everything?
    } elsif ($ARGV[1] eq "wipe") {
        logmsg "This will delete ALL session data in elastic search! (It does not delete the pcap files on disk or user info.)\n\
        waitFor("WIPE", "do you want to wipe everything?
    } elsif ($ARGV[1] eq "clean") {
        waitFor("CLEAN", "do you want to clean everything?
    }
    logmsg "Erasing\
    esDelete("/${PREFIX}tags_v3",
    esDelete("/${PREFIX}tags_v2",
    esDelete("/${PREFIX}tags",
    esDelete("/${PREFIX}sequence",
    esDelete("/${PREFIX}sequence_v1",
    esDelete("/${PREFIX}sequence_v2",
    esDelete("/${PREFIX}sequence_v3",
    esDelete("/${PREFIX}files_v6",
    esDelete("/${PREFIX}files_v5",
    esDelete("/${PREFIX}files_v4",
    esDelete("/${PREFIX}files_v3",
    esDelete("/${PREFIX}files",
    esDelete("/${PREFIX}stats",
    esDelete("/${PREFIX}stats_v1",
    esDelete("/${PREFIX}stats_v2",
    esDelete("/${PREFIX}stats_v3",
    esDelete("/${PREFIX}stats_v4",
    esDelete("/${PREFIX}dstats",
    esDelete("/${PREFIX}fields",
    esDelete("/${PREFIX}dstats_v1",
    esDelete("/${PREFIX}dstats_v2",
    esDelete("/${PREFIX}dstats_v3",
    esDelete("/${PREFIX}dstats_v4",
    esDelete("/${PREFIX}sessions-*",
    esDelete("/${PREFIX}sessions2-*",
    esDelete("/_template/${PREFIX}template_1",
    esDelete("/_template/${PREFIX}sessions_template",
    esDelete("/_template/${PREFIX}sessions2_template",
    esDelete("/${PREFIX}fields",
    esDelete("/${PREFIX}fields_v1",
    esDelete("/${PREFIX}fields_v2",
    esDelete("/${PREFIX}fields_v3",
    esDelete("/${PREFIX}history_v1-*",
    esDelete("/_template/${PREFIX}history_v1_template",
    esDelete("/${PREFIX}hunts_v1",
    esDelete("/${PREFIX}hunts_v2",
    esDelete("/${PREFIX}lookups_v1",
    if ($ARGV[1] =~ /^(init|clean)/) {
        esDelete("/${PREFIX}users_v5",
        esDelete("/${PREFIX}users_v6",
        esDelete("/${PREFIX}users_v7",
        esDelete("/${PREFIX}users",
        esDelete("/${PREFIX}queries",
        esDelete("/${PREFIX}queries_v1",
        esDelete("/${PREFIX}queries_v2",
        esDelete("/${PREFIX}queries_v3",
    }
    esDelete("/tagger",

    sleep(

    exit 0 if ($ARGV[1] =~ "clean

    logmsg "Creating\
    sequenceCreate
    filesCreate
    statsCreate
    dstatsCreate
    sessions2Update
    fieldsCreate
    historyUpdate
    huntsCreate
    lookupsCreate
    if ($ARGV[1] =~ "init") {
        usersCreate
        queriesCreate
    }
} elsif ($ARGV[1] =~ /^restore$/) {

    logmsg "It is STRONGLY recommended that you stop ALL moloch captures and viewers before proceeding.\

    dbCheckForActivity

    my @indexes = ("users", "sequence", "stats", "queries", "hunts", "files", "fields", "dstats", "lookups
    my @filelist =
    foreach my $index (@indexes) {  list of data, settings, and mappings files
        push(@filelist, "$ARGV[2].${PREFIX}${index}.json\n") if (-e "$ARGV[2].${PREFIX}${index}.json
        push(@filelist, "$ARGV[2].${PREFIX}${index}.settings.json\n") if (-e "$ARGV[2].${PREFIX}${index}.settings.json
        push(@filelist, "$ARGV[2].${PREFIX}${index}.mappings.json\n") if (-e "$ARGV[2].${PREFIX}${index}.mappings.json
    }
    foreach my $index ("sessions2", "history") {  list of templates
        @filelist = (@filelist, "$ARGV[2].${PREFIX}${index}.template.json\n") if (-e "$ARGV[2].${PREFIX}${index}.template.json
    }

    push(@filelist, "$ARGV[2].${PREFIX}aliases.json\n") if (-e "$ARGV[2].${PREFIX}aliases.json

    my @directory = split(/\//,$ARGV[2
    my $basename = $directory[scalar(@directory)-
    splice(@directory, scalar(@directory)-1,
    my $path = join("/", @director

    die "Cannot find files start with ${basename}.${PREFIX} in $path" if (scalar(@filelist) ==


    logmsg "\nFollowing files will be used for restore\n\n@filelist\n\

    waitFor("RESTORE", "do you want to restore? This will delete ALL data [@indexes] but sessions and history and restore from backups: files start with $basename in $path

    logmsg "\nStarting Restore...\n\

    logmsg "Erasing data ...\n\

    esDelete("/${PREFIX}tags_v3",
    esDelete("/${PREFIX}tags_v2",
    esDelete("/${PREFIX}tags",
    esDelete("/${PREFIX}sequence",
    esDelete("/${PREFIX}sequence_v1",
    esDelete("/${PREFIX}sequence_v2",
    esDelete("/${PREFIX}sequence_v3",
    esDelete("/${PREFIX}files_v6",
    esDelete("/${PREFIX}files_v5",
    esDelete("/${PREFIX}files_v4",
    esDelete("/${PREFIX}files_v3",
    esDelete("/${PREFIX}files",
    esDelete("/${PREFIX}stats",
    esDelete("/${PREFIX}stats_v1",
    esDelete("/${PREFIX}stats_v2",
    esDelete("/${PREFIX}stats_v3",
    esDelete("/${PREFIX}stats_v4",
    esDelete("/${PREFIX}dstats",
    esDelete("/${PREFIX}dstats_v1",
    esDelete("/${PREFIX}dstats_v2",
    esDelete("/${PREFIX}dstats_v3",
    esDelete("/${PREFIX}dstats_v4",
    esDelete("/${PREFIX}fields",
    esDelete("/${PREFIX}fields_v1",
    esDelete("/${PREFIX}fields_v2",
    esDelete("/${PREFIX}fields_v3",
    esDelete("/${PREFIX}hunts_v2",
    esDelete("/${PREFIX}hunts_v1",
    esDelete("/${PREFIX}hunts",
    esDelete("/${PREFIX}users_v3",
    esDelete("/${PREFIX}users_v4",
    esDelete("/${PREFIX}users_v5",
    esDelete("/${PREFIX}users_v6",
    esDelete("/${PREFIX}users_v7",
    esDelete("/${PREFIX}users",
    esDelete("/${PREFIX}queries",
    esDelete("/${PREFIX}queries_v1",
    esDelete("/${PREFIX}queries_v2",
    esDelete("/${PREFIX}queries_v3",
    esDelete("/${PREFIX}lookups_v1",
    esDelete("/_template/${PREFIX}template_1",
    esDelete("/_template/${PREFIX}sessions_template",
    esDelete("/_template/${PREFIX}sessions2_template",
    esDelete("/_template/${PREFIX}history_v1_template",

    logmsg "Importing settings...\n\
    foreach my $index (@indexes) {  import settings
        if (-e "$ARGV[2].${PREFIX}${index}.settings.json") {
            open(my $fh, "<", "$ARGV[2].${PREFIX}${index}.settings.json
            my $data = do { local  <$fh>
            $data = from_json($dat
            my @index = keys %{$dat
            delete $data->{$index[0]}->{settings}->{index}->{creation_dat
            delete $data->{$index[0]}->{settings}->{index}->{provided_nam
            delete $data->{$index[0]}->{settings}->{index}->{uui
            delete $data->{$index[0]}->{settings}->{index}->{versio
            my $settings = to_json($data->{$index[0]
            esPut("/$index[0]?master_timeout=${ESTIMEOUT}s", $setting
            close($f
        }
    }

    logmsg "Importing aliases...\n\
    if (-e "$ARGV[2].${PREFIX}aliases.json") {  import alias
            open(my $fh, "<", "$ARGV[2].${PREFIX}aliases.json
            my $data = do { local  <$fh>
            $data = from_json($dat
            foreach my $alias (@{$data}) {
                esAlias("add", $alias->{index}, $alias->{alias},
            }
    }

    logmsg "Importing mappings...\n\
    foreach my $index (@indexes) {  import mappings
        if (-e "$ARGV[2].${PREFIX}${index}.mappings.json") {
            open(my $fh, "<", "$ARGV[2].${PREFIX}${index}.mappings.json
            my $data = do { local  <$fh>
            $data = from_json($dat
            my @index = keys %{$dat
            my $mappings = $data->{$index[0]}->{mapping
            my @type = keys %{$mapping
            esPut("/$index[0]/$type[0]/_mapping?master_timeout=${ESTIMEOUT}s&pretty&include_type_name=true", to_json($mappings
            close($f
        }
    }

    logmsg "Importing documents...\n\
    foreach my $index (@indexes) {  import documents
        if (-e "$ARGV[2].${PREFIX}${index}.json") {
            open(my $fh, "<", "$ARGV[2].${PREFIX}${index}.json
            my $data = do { local  <$fh>
            esPost("/_bulk", $dat
            close($f
        }
    }

    logmsg "Importing templates for Sessions and History...\n\
    my @templates = ("sessions2", "history
    foreach my $template (@templates) {  import templates
        if (-e "$ARGV[2].${PREFIX}${template}.template.json") {
            open(my $fh, "<", "$ARGV[2].${PREFIX}${template}.template.json
            my $data = do { local  <$fh>
            $data = from_json($dat
            my @template_name = keys %{$dat
            esPut("/_template/$template_name[0]?master_timeout=${ESTIMEOUT}s&include_type_name=true", to_json($data->{$template_name[0]}
            close($f
        }
    }

    foreach my $template (@templates) {  update mappings
        if (-e "$ARGV[2].${PREFIX}${template}.template.json") {
            open(my $fh, "<", "$ARGV[2].${PREFIX}${template}.template.json
            my $data = do { local  <$fh>
            $data = from_json($dat
            my @template_name = keys %{$dat
            my $mapping = $data->{$template_name[0]}->{mapping
            if (($template cmp "sessions2") == 0 && $UPGRADEALLSESSIONS) {
                my $indices = esGet("/${PREFIX}sessions2-*/_alias",
                logmsg "Updating sessions2 mapping for ", scalar(keys %{$indices}), " indices\n" if (scalar(keys %{$indices}) !=
                foreach my $i (keys %{$indices}) {
                    progress("$i
                    esPut("/$i/session/_mapping?master_timeout=${ESTIMEOUT}s&include_type_name=true", to_json($mapping),
                }
                logmsg "\
            } elsif (($template cmp "history") == 0) {
                my $indices = esGet("/${PREFIX}history_v1-*/_alias",
                logmsg "Updating history mapping for ", scalar(keys %{$indices}), " indices\n" if (scalar(keys %{$indices}) !=
                foreach my $i (keys %{$indices}) {
                    progress("$i
                    esPut("/$i/history/_mapping?master_timeout=${ESTIMEOUT}s&include_type_name=true", to_json($mapping),
                }
                logmsg
            }
            close($f
        }
    }
    logmsg "Finished Restore.
} else {

 Remaing is upgrade or upgradenoprompt

 For really old versions don't support upgradenoprompt
    if ($main::versionNumber < 57) {
        logmsg "Can not upgrade directly, please upgrade to Moloch 1.7.x or 1.8.x first. (Db version $main::versionNumber)\n\
        exit
    }

    if ($health->{status} eq "red") {
        logmsg "Not auto upgrading when elasticsearch status is red.\n\
        waitFor("RED", "do you want to really want to upgrade?
    } elsif ($ARGV[1] ne "upgradenoprompt") {
        logmsg "Trying to upgrade from version $main::versionNumber to version $VERSION.\n\
        waitFor("UPGRADE", "do you want to upgrade?
    }

    logmsg "Starting Upgrade\

    esDelete("/${PREFIX}dstats_v2/version/version",
    esDelete("/${PREFIX}dstats_v3/version/version",

    if ($main::versionNumber <= 62) {
        dbCheckForActivity
        esPost("/_flush/synced", "",
        sequenceUpgrade
        createNewAliasesFromOld("fields", "fields_v3", "fields_v2", \&fieldsCreat
        createNewAliasesFromOld("queries", "queries_v3", "queries_v2", \&queriesCreat
        createNewAliasesFromOld("files", "files_v6", "files_v5", \&filesCreat
        createNewAliasesFromOld("users", "users_v7", "users_v6", \&usersCreat
        createNewAliasesFromOld("dstats", "dstats_v4", "dstats_v3", \&dstatsCreat
        createNewAliasesFromOld("stats", "stats_v4", "stats_v3", \&statsCreat
        createNewAliasesFromOld("hunts", "hunts_v2", "hunts_v1", \&huntsCreat

        if ($main::versionNumber <= 60) {
            lookupsCreate
        } else {
            lookupsUpdate
        }

        historyUpdate
        sessions2Update

        setPriority

        checkForOld5Indices
        checkForOld6Indices
    } elsif ($main::versionNumber <= 64) {
        checkForOld5Indices
        checkForOld6Indices
        sessions2Update
        historyUpdate
        lookupsUpdate
    } else {
        logmsg "db.pl is hosed\
    }
}

if ($DOHOTWARM) {
    esPut("/${PREFIX}stats_v4,${PREFIX}dstats_v4,${PREFIX}fields_v3,${PREFIX}files_v6,${PREFIX}sequence_v3,${PREFIX}users_v7,${PREFIX}queries_v3,${PREFIX}hunts_v2,${PREFIX}history*/_settings?master_timeout=${ESTIMEOUT}s&allow_no_indices=true&ignore_unavailable=true", "{\"index.routing.allocation.require.molochtype\": \"warm\"}
} else {
    esPut("/${PREFIX}stats_v4,${PREFIX}dstats_v4,${PREFIX}fields_v3,${PREFIX}files_v6,${PREFIX}sequence_v3,${PREFIX}users_v7,${PREFIX}queries_v3,${PREFIX}hunts_v2,${PREFIX}history*/_settings?master_timeout=${ESTIMEOUT}s&allow_no_indices=true&ignore_unavailable=true", "{\"index.routing.allocation.require.molochtype\": null}
}

logmsg Finished\

sleep
