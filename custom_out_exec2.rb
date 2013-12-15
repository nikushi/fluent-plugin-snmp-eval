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

