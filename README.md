https://github.com/iij/fluent-plugin-snmp の動作検証

## テスト項目(1)
### 機器からsnmp getでデータ取得

    <source>
      type snmp
      tag snmp.localhost
      # nodes name, value #コメントアウト
      host 127.0.0.1
      port 10161
      community public
      mib sysContact.0, sysDescr.0, sysName.0
      method_type get
      polling_time 5
      polling_type async_run
    </source>

出力結果

    2013-12-15 23:35:00 +0900 snmp.localhost: {"name":"SNMPv2-MIB::sysContact.0","value":"Root <root@localhost> (configure /etc/snmp/snmp.local.conf)"}
    2013-12-15 23:35:00 +0900 snmp.localhost: {"name":"SNMPv2-MIB::sysDescr.0","value":"Linux localhost.localdomain 2.6.32-358.6.2.el6.x86_64 #1 SMP Thu May 16 20:59:36 UTC 2013 x86_64"}
    2013-12-15 23:35:00 +0900 snmp.localhost: {"name":"SNMPv2-MIB::sysName.0","value":"localhost.localdomain"}

mibに指定した個数3個と同じメッセージが発生する

## テスト項目(2)
### 機器からsnmp walkでデータ取得

設定

    <source>
      type snmp
      tag snmp.localhost
      nodes name, value
      host 127.0.0.1
      port 10161
      community public
      mib ifDescr, ifInOctets, ifOutOctets
      method_type walk
      polling_time 5
      polling_type async_run
    </source>

    <match *.*>
      type stdout
    </match>

結果

    2013-12-15 23:40:35 +0900 snmp.localhost: {"name":"IF-MIB::ifDescr.1","value":"lo"}
    2013-12-15 23:40:35 +0900 snmp.localhost: {"name":"IF-MIB::ifInOctets.1","value":"0"}
    2013-12-15 23:40:35 +0900 snmp.localhost: {"name":"IF-MIB::ifOutOctets.1","value":"0"}
    2013-12-15 23:40:35 +0900 snmp.localhost: {"name":"IF-MIB::ifDescr.2","value":"eth0"}
    2013-12-15 23:40:35 +0900 snmp.localhost: {"name":"IF-MIB::ifInOctets.2","value":"162979084"}
    2013-12-15 23:40:35 +0900 snmp.localhost: {"name":"IF-MIB::ifOutOctets.2","value":"4050991"}
    2013-12-15 23:40:35 +0900 snmp.localhost: {"name":"IF-MIB::ifDescr.3","value":"eth1"}
    2013-12-15 23:40:35 +0900 snmp.localhost: {"name":"IF-MIB::ifInOctets.3","value":"896826"}
    2013-12-15 23:40:35 +0900 snmp.localhost: {"name":"IF-MIB::ifOutOctets.3","value":"914"}

walkして得た各varbindの値個数分のメッセージを出力する

## テスト項目(3)
### out_executorを使ってwalkを1メッセージにまとめる
設定

    <source>
      type snmp
      tag snmp.localhost
      nodes name, value
      host 127.0.0.1
      port 10161
      community public
      mib ifDescr, ifInOctets, ifOutOctets, ifInErrors, ifOutErrors, ifInDiscards, ifOutDiscards
      out_executor custom_out_exec.rb
      polling_time 5
      polling_type async_run
    </source>

    <match *.*>
      type stdout
    </match>

custom_out_exec.rb

    module Fluent
      class SnmpInput
        def out_exec manager, opts={}
          record = {}
          time = Time.now.to_i
          time = time - time  % 5

          manager.walk(opts[:mib]) do |row|
            desc = row[0].value.to_s #ifDescr
            row.each_with_index do |vb, i|
              next if i == 0
              key = nil
              case vb.name.to_s
              when /if(In|Out)Octets\./
                direction = $1.downcase
                key = "if_traffic/#{desc} (#{direction}bound)"
              when /if(In|Out)Errors\./
                direction = $1.downcase
                key = "if_error/#{desc} (#{direction}bound)"
              when /if(In|Out)Discards\./
                direction = $1.downcase
                key = "if_discard/#{desc} (#{direction}bound)"
              end
              record[key] = vb.value.to_s
            end
          end
          Engine.emit opts[:tag], time, record
        end
      end
    end

結果

    2013-12-16 00:36:15 +0900 snmp.localhost: {"if_traffic/lo (inbound)":"0","if_traffic/lo (outbound)":"0","if_error/lo (inbound)":"0","if_error/lo (outbound)":"0","if_discard/lo (inbound)":"0","if_discard/lo (outbound)":"0","if_traffic/eth0 (inbound)":"163132545","if_traffic/eth0 (outbound)":"4210505","if_error/eth0 (inbound)":"0","if_error/eth0 (outbound)":"0","if_discard/eth0 (inbound)":"0","if_discard/eth0 (outbound)":"0","if_traffic/eth1 (inbound)":"915306","if_traffic/eth1 (outbound)":"914","if_error/eth1 (inbound)":"0","if_error/eth1 (outbound)":"0","if_discard/eth1 (inbound)":"0","if_discard/eth1 (outbound)":"0"}

walk結果を全てまとめて1メッセージにして出力するout executorの例。

## テスト項目(4)
### out_executorを使ってrow毎にメッセージをまとめる

テスト(3)のうち、out_executorのスクリプトのみ変更

    module Fluent
      class SnmpInput
        def out_exec manager, opts={}
          manager.walk(opts[:mib]) do |row|
            record = {}
            time = Time.now.to_i
            time = time - time  % 5

            desc = row[0].value.to_s #ifDescr
            row.each_with_index do |vb, i|
              next if i == 0
              key = nil
              case vb.name.to_s
              when /if(In|Out)Octets\./
                direction = $1.downcase
                key = "if_traffic/#{desc} (#{direction}bound)"
              when /if(In|Out)Errors\./
                direction = $1.downcase
                key = "if_error/#{desc} (#{direction}bound)"
              when /if(In|Out)Discards\./
                direction = $1.downcase
                key = "if_discard/#{desc} (#{direction}bound)"
              end
              record[key] = vb.value.to_s
            end
            Engine.emit opts[:tag], time, record
          end
        end
      end
    end

結果

    2013-12-16 00:43:05 +0900 snmp.localhost: {"if_traffic/lo (inbound)":"0","if_traffic/lo (outbound)":"0","if_error/lo (inbound)":"0","if_error/lo (outbound)":"0","if_discard/lo (inbound)":"0","if_discard/lo (outbound)":"0"}
    2013-12-16 00:43:05 +0900 snmp.localhost: {"if_traffic/eth0 (inbound)":"163134123","if_traffic/eth0 (outbound)":"4212155","if_error/eth0 (inbound)":"0","if_error/eth0 (outbound)":"0","if_discard/eth0 (inbound)":"0","if_discard/eth0 (outbound)":"0"}
    2013-12-16 00:43:05 +0900 snmp.localhost: {"if_traffic/eth1 (inbound)":"917438","if_traffic/eth1 (outbound)":"914","if_error/eth1 (inbound)":"0","if_error/eth1 (outbound)":"0","if_discard/eth1 (inbound)":"0","if_discard/eth1 (outbound)":"0"}

インタフェース毎にメッセージを分割した。

## コンフィグに関するメモ

### polling_type
* `run`(default) offset秒(デフォルト毎分0秒)のときに開始する
* `async_run` 開始タイミングを同期を取らず、即座に実行

### polling_offset
デフォルト=0, `polling_type=run`の時のoffset秒を設定

