class Vcard

  CONTENT = /\s*([^\r\n]+)/

  def self.parse(data)
    data.split(/BEGIN:VCARD|END:VCARD/).collect do |card|
      card.strip!
      next if card == ""

      vcard = {}

      card.split(/\r?\n/).each do |line|
        case line
        when /^N:#{CONTENT}/
          vcard[:last_name], vcard[:first_name] = $1.split(";")[0..1]
        when /^ORG:#{CONTENT}/
          vcard[:organization] = $1.split(";").first
        when /^TEL/
          key, value = line.split(":", 2)
          next unless key =~ /(CELL|WORK)/
          key = case $1
            when "CELL" then "mobile_phone"
            when "WORK" then "office_phone"
            else "#{$1.downcase}_phone"
          end
          vcard[key.intern] = value
        when /^EMAIL/
          key, value = line.split(":", 2)

          # We only store one email, so take the first or the preferred email.
          next if vcard[:email] && !key.match(/pref/)

          vcard[:email] = value
        when /^(item1.)?ADR/
          # We only store one address, so take the first.
          next if vcard[:address]

          key, value = line.split(":", 2)
          address, city, state, postal_code, country = *value.split(";")[2..-1]
          address = address.split('\n')

          vcard[:address] = address[0]
          vcard[:address2] = address[1]
          vcard[:city] = city
          vcard[:state] = state
          vcard[:postal_code] = postal_code
          vcard[:country] = country
        else
          next
        end
      end

      vcard
    end.compact
  end
end